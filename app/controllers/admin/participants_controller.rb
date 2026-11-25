class Admin::ParticipantsController < ApplicationController
  SORT_COLUMNS = %w[number name email country rank status].freeze
  STATUS_FILTERS = Participant::STATUSES
  PARTICIPANT_TYPES = %w[player visitor].freeze

  before_action :require_admin!
  before_action :set_participant, only: [:show, :edit, :update, :destroy, :add_payment]
  before_action :set_overview_params, only: [:index, :show, :edit, :update, :destroy]

  def add_payment
    return redirect_to edit_admin_participant_path(@participant), alert: "Only players can purchase a ticket." unless @participant.player?
    return redirect_to edit_admin_participant_path(@participant), alert: "This participant already has a valid paid ticket." if @participant.valid_admission?

    orders = @participant.participant_tickets.where(invalidated_at: nil).joins(product: :order).where(orders: { cancelled_at: nil }).includes(product: { order: :payments }).map { |ticket| ticket.order }.compact.uniq.select { |order| !order.payments.completed.exists? }
    if orders.many?
      @payment_orders = orders
      render "admin/participants/select_payment_order"
      return
    elsif orders.one?
      return redirect_to new_admin_order_payment_path(orders.first)
    end

    order = nil
    @participant.user.with_lock do
      if (draft = @participant.user.orders.drafts.first)
        return redirect_to edit_admin_order_path(draft), alert: "The participant's User already has draft Order ##{draft.id}. Review it before creating another Order."
      end
      raise ActiveRecord::RecordNotSaved, "Participant cannot purchase another ticket." unless @participant.can_purchase_ticket?
      order = @participant.user.orders.create!(status: "draft")
      @participant.participant_tickets.create!
      order.reload
      raise ActiveRecord::RecordNotSaved, "The ticket could not be added to its new draft Order." unless order.products.exists?
    end
    redirect_to edit_admin_order_path(order), notice: "Review the new ticket Order before submitting it."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    redirect_to edit_admin_participant_path(@participant), alert: e.message
  end

  def index
    participants = Participant.includes(:user, participant_tickets: { product: { order: :payments } })

    @countries = Participant.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)
    @country_filter = params[:country].to_s.upcase.presence
    @status_filters = @overview_params[:status] || []
    @payment_status_filters = @overview_params[:payment_status] || []
    @type_filter = PARTICIPANT_TYPES.include?(params[:type]) ? params[:type] : nil
    @name_filter = params[:name].to_s.strip
    @sort = permitted_sort
    @direction = permitted_direction

    participants = participants.where(country: @country_filter) if @country_filter.present?
    participants = participants.where(participant_type: @type_filter) if @type_filter.present?
    if @name_filter.present?
      name = "%#{ActiveRecord::Base.sanitize_sql_like(@name_filter)}%"
      participants = participants.where(
        "first_name ILIKE :name OR last_name ILIKE :name OR CONCAT_WS(' ', first_name, last_name) ILIKE :name",
        name: name
      )
    end

    @participants = sorted_participants(participants).to_a
    @participants.select! { |participant| @status_filters.include?(participant.status) } if @status_filters.any?
    if @payment_status_filters.any?
      @participants.select! { |participant| @payment_status_filters.include?(helpers.admin_participant_payment_status(participant).first) }
    end
    if @sort == "status"
      @participants.sort_by! do |participant|
        index = Participant::STATUSES.index(participant.status)
        [@direction == :desc ? -index : index, participant.last_name, participant.first_name, participant.id]
      end
    end
    @latest_payments_by_participant_id = latest_payments_by_participant_id(@participants)
  end

  def show
    @participant = Participant.includes(:user, participant_tickets: { product: { order: :payments } }).find(@participant.id)
    @tickets = @participant.participant_tickets.sort_by { |ticket| [ticket.created_at, ticket.id] }.reverse
    @valid_ticket = @tickets.find(&:valid_admission?)
  end

  def edit
  end

  # Queues a background refresh of rank and rating from the European Go
  # Database for every participant with a valid EGD pin.
  def sync_egd
    EgdSyncJob.perform_later
    redirect_to admin_participants_path, notice: "EGD synchronization has been started."
  end

  def update
    if @participant.update(participant_params)
      redirect_to admin_participants_path(**@overview_params), notice: "Participant was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @participant.deletable?
      alert = if @participant.charged_back?
        "Participants with charged-back payments cannot be deleted."
      elsif @participant.refunded?
        "Participants with refunded payments cannot be deleted."
      elsif @participant.paid?
        "Participants with a successful payment cannot be deleted."
      elsif @participant.blocking_payments?
        "Participants with an open or pending payment cannot be deleted."
      elsif @participant.submitted_ticket_order?
        "Participants in a submitted order cannot be deleted."
      else
        "Participants with an open or pending payment cannot be deleted."
      end
      redirect_to admin_participants_path(**@overview_params), alert: alert
      return
    end

    user = @participant.user
    last_participant_for_user = @participant.only_participant_for_user?
    delete_user_requested = ActiveModel::Type::Boolean.new.cast(params[:delete_user])
    eligible_for_account_delete = user.present? && user != current_user && last_participant_for_user && user.account_deletable?
    delete_user = delete_user_requested && eligible_for_account_delete

    ActiveRecord::Base.transaction do
      @participant.destroy!
      user.destroy! if delete_user
    end

    notice = if delete_user
      "Participant and user account were successfully deleted."
    elsif delete_user_requested && user.present? && last_participant_for_user && !eligible_for_account_delete
      "Participant was successfully deleted. The user account was kept."
    else
      "Participant was successfully deleted."
    end
    redirect_to admin_participants_path(**@overview_params), notice: notice
  end

  private

  def set_overview_params
    statuses = Array(params[:status]).select { |value| value.is_a?(String) && STATUS_FILTERS.include?(value) }.uniq
    payment_statuses = Array(params[:payment_status]).select { |value| value.is_a?(String) && ApplicationHelper::ADMIN_PARTICIPANT_PAYMENT_STATUSES.include?(value) }.uniq
    @overview_params = {
      country: params[:country].to_s.upcase.presence,
      type: PARTICIPANT_TYPES.include?(params[:type]) ? params[:type] : nil,
      name: params[:name].to_s.strip.presence,
      status: statuses.presence,
      payment_status: payment_statuses.presence,
      sort: SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : nil,
      direction: %w[asc desc].include?(params[:direction]) ? params[:direction] : nil
    }.compact
  end

  def set_participant
    @participant = Participant.find_by!(uuid: params[:id])
  end

  def permitted_sort
    SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "name"
  end

  def permitted_direction
    return params[:direction].to_sym if %w[asc desc].include?(params[:direction])

    # Default ordering (no explicit sort) is ascending; column clicks default to ascending too.
    :asc
  end

  def sorted_participants(participants)
    table = Participant.arel_table

    clauses =
      case @sort
      when "number"
        [ordered(table[:id])]
      when "email"
        [ordered(nullif_blank(table[:email]))]
      when "country"
        [ordered(table[:country])]
      when "club"
        [ordered(nullif_blank(table[:club]))]
      when "type"
        [ordered(table[:participant_type])]
      when "rank"
        [ordered(table[:rank]), ordered(table[:rating])]
      when "rating"
        [ordered(table[:rating])]
      else
        [ordered(table[:last_name]), ordered(table[:first_name])]
      end

    participants.order(*clauses, table[:last_name].asc, table[:first_name].asc, table[:id].asc)
  end

  def ordered(column)
    ordering = @direction == :desc ? column.desc : column.asc
    ordering.nulls_last
  end

  def nullif_blank(column)
    Arel::Nodes::NamedFunction.new("NULLIF", [column, Arel::Nodes.build_quoted("")])
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :participant_type, :age_group, :country, :club, :rank, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option, :admin_status)
  end

  def latest_payments_by_participant_id(participants)
    participant_ids = participants.map(&:id)
    return {} if participant_ids.empty?

    Payment
      .joins(order: :products)
      .joins("INNER JOIN participant_tickets ON participant_tickets.id = products.productable_id AND products.productable_type = 'ParticipantTicket'")
      .select(Arel.sql("DISTINCT ON (participant_tickets.participant_id) payments.*, participant_tickets.participant_id AS payee_id"))
      .where(participant_tickets: { participant_id: participant_ids })
      .order(Arel.sql("participant_tickets.participant_id, payments.created_at DESC, payments.id DESC"))
      .index_by(&:payee_id)
  end
end
