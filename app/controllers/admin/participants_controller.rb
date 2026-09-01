class Admin::ParticipantsController < ApplicationController
  SORT_COLUMNS = %w[name email country club type rank rating status].freeze
  STATUS_FILTERS = %w[pending confirmed paid].freeze

  before_action :require_admin!
  before_action :set_participant, only: [:edit, :update, :destroy]

  def index
    participants = Participant.includes(:payments)

    @countries = Participant.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)
    @country_filter = params[:country].to_s.upcase.presence
    @status_filter = STATUS_FILTERS.include?(params[:status]) ? params[:status] : nil
    @sort = permitted_sort
    @direction = permitted_direction

    participants = participants.where(country: @country_filter) if @country_filter.present?
    participants = filtered_by_status(participants, @status_filter) if @status_filter.present?

    @participants = sorted_participants(participants).to_a
    @latest_payments_by_participant_id = latest_payments_by_participant_id(@participants)
  end

  def edit
  end

  def update
    if @participant.update(participant_params)
      redirect_to admin_participants_path, notice: "Participant was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    unless @participant.deletable?
      alert = if @participant.paid?
        "Participants with a successful payment cannot be deleted."
      else
        "Participants with an open or pending payment cannot be deleted."
      end
      redirect_to admin_participants_path, alert: alert
      return
    end

    user = @participant.user
    last_participant_for_user = @participant.only_participant_for_user?
    delete_user_requested = ActiveModel::Type::Boolean.new.cast(params[:delete_user])
    delete_user = delete_user_requested &&
      user.present? && user != current_user && last_participant_for_user

    ActiveRecord::Base.transaction do
      @participant.destroy!
      user.destroy! if delete_user
    end

    notice = if delete_user
      "Participant and user account were successfully deleted."
    elsif delete_user_requested && user.present? && user == current_user && last_participant_for_user
      "Participant was successfully deleted. The user account was kept."
    else
      "Participant was successfully deleted."
    end
    redirect_to admin_participants_path, notice: notice
  end

  private

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

  # Restricts the list to participants whose derived registration_status matches
  # the requested filter, mirroring the Participant#registration_status logic:
  # Paid takes precedence over Confirmed, which takes precedence over Pending.
  def filtered_by_status(participants, status)
    paid_ids = Payment.completed.select(:participant_id)

    case status
    when "paid"
      participants.where(id: paid_ids)
    when "confirmed"
      participants.where.not(confirmed_at: nil).where.not(id: paid_ids)
    when "pending"
      participants.where(confirmed_at: nil).where.not(id: paid_ids)
    else
      participants
    end
  end

  def sorted_participants(participants)
    table = Participant.arel_table

    clauses =
      case @sort
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
      when "status"
        return status_sorted_participants(participants)
      else
        [ordered(table[:last_name]), ordered(table[:first_name])]
      end

    participants.order(*clauses, table[:last_name].asc, table[:first_name].asc, table[:id].asc)
  end

  # Registration status is derived from DB columns, expressed as a SQL CASE so
  # sorting stays at the database level. Pending < Confirmed < Paid.
  def status_sorted_participants(participants)
    table = Participant.arel_table
    paid_subquery = Payment.completed.select(:participant_id).to_sql
    dir = @direction == :desc ? "DESC" : "ASC"
    status_order = Arel.sql(
      "CASE WHEN participants.id IN (#{paid_subquery}) THEN 2 " \
      "WHEN participants.confirmed_at IS NOT NULL THEN 1 " \
      "ELSE 0 END #{dir}"
    )
    participants.order(status_order, table[:last_name].asc, table[:first_name].asc, table[:id].asc)
  end

  def ordered(column)
    ordering = @direction == :desc ? column.desc : column.asc
    ordering.nulls_last
  end

  def nullif_blank(column)
    Arel::Nodes::NamedFunction.new("NULLIF", [column, Arel::Nodes.build_quoted("")])
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :participant_type, :age_group, :country, :club, :rank, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end

  def latest_payments_by_participant_id(participants)
    participant_ids = participants.map(&:id)
    return {} if participant_ids.empty?

    Payment
      .select(Arel.sql("DISTINCT ON (participant_id) payments.*"))
      .where(participant_id: participant_ids)
      .order(Arel.sql("participant_id, created_at DESC, id DESC"))
      .index_by(&:participant_id)
  end
end
