class Admin::OrdersController < ApplicationController
  SORT_COLUMNS = %w[order_id submitted user cancelled_at total].freeze
  STATUS_FILTERS = %w[awaiting pending paid failed canceled expired order_cancelled].freeze

  before_action :require_admin!
  before_action :set_order, only: [:show, :edit, :update, :submit, :cancel, :remove_product, :discard, :participants, :add_participant]

  def index
    @draft_orders = Order.drafts.includes(:user, :products).order(created_at: :desc)
    @sort = SORT_COLUMNS.include?(params[:sort]) ? params[:sort] : "submitted"
    @direction = params[:direction] == "asc" ? :asc : :desc
    requested_statuses = params[:status].is_a?(Array) ? params[:status] : [params[:status]]
    @status_filters = requested_statuses.select { |status| STATUS_FILTERS.include?(status) }.uniq

    orders = Order.submitted.includes(:user, :products, :payments).to_a
    preload_order_display_associations(orders)
    orders.select! { |order| @status_filters.include?(status_filter_key(order)) } if @status_filters.any?
    @orders = sort_orders(orders)
  end

  def new
    @users = User.order(:email)
    @order = Order.new(user: current_user)
  end

  def create
    owner = User.find(order_params[:user_id])
    participant_ids = Array(order_params[:participant_ids]).reject(&:blank?).uniq
    if participant_ids.one?
      participant = owner.participants.find_by(id: participant_ids.first)
      if participant
        existing = participant.participant_tickets.where(invalidated_at: nil).joins(product: :order)
          .where(orders: { cancelled_at: nil }).includes(product: { order: :payments }).map(&:order).reject(&:closed?).uniq
        if existing.one?
          return redirect_to admin_order_path(existing.first), notice: "This participant already has a ticket in Order ##{existing.first.id}. Review the Order."
        end
      end
    end
    @order = nil
    owner.with_lock do
      if (draft = owner.orders.drafts.first)
        return redirect_to edit_admin_order_path(draft), alert: "#{owner.display_name} already has draft Order ##{draft.id}. Review it before creating another order."
      end
      @order = owner.orders.create!(status: "draft")
      add_selected_products!(@order)
    end
    redirect_to edit_admin_order_path(@order), notice: "Draft Order ##{@order.id} was created for review."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotFound => e
    @order ||= Order.new(user_id: order_params[:user_id])
    @order.errors.add(:base, e.message)
    load_order_form
    render :new, status: :unprocessable_entity
  end

  def edit
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    load_order_form
  end

  def update
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    if order_params[:user_id].present? && order_params[:user_id].to_i != @order.user_id
      owner = User.find(order_params[:user_id])
      if (draft = owner.orders.drafts.where.not(id: @order.id).first)
        flash[:existing_draft_id] = draft.id
        return redirect_to edit_admin_order_path(@order), alert: "#{owner.display_name} already has draft Order ##{draft.id}. Review it before changing the owner."
      end
      @order.change_draft_owner!(owner)
    else
      ActiveRecord::Base.transaction { add_selected_products!(@order) }
    end
    redirect_to edit_admin_order_path(@order), notice: "Order products were updated. Review the full Order before submission."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotFound => e
    @order.errors.add(:base, e.message)
    load_order_form
    render :edit, status: :unprocessable_entity
  end

  def participants
    return head :not_found unless @order.editable?

    query = params[:q].to_s.strip
    if query.length < 2
      return render json: [] if request.format.json?

      @search_query = query
      @search_matches = []
      load_order_form
      return render :edit
    end

    prefix = "#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    paid_participant_ids = ParticipantTicket.eligible_for_registration_status.joins(product: { order: :payments })
      .merge(Payment.completed).select(:participant_id)
    scope = Participant.includes(:user).where(participant_type: "player")
      .where.not(id: paid_participant_ids)
      .where("first_name ILIKE :prefix OR last_name ILIKE :prefix OR CONCAT_WS(' ', first_name, last_name) ILIKE :prefix", prefix: prefix)
    scope = scope.where(user_id: @order.user_id) if @order.products.where(productable_type: "ParticipantTicket").exists?
    matches = scope.order(:last_name, :first_name, :id).limit(10).map do |participant|
      { id: participant.id, label: "#{participant.first_name} #{participant.last_name} · #{participant.user.email}" }
    end
    respond_to do |format|
      format.json { render json: matches }
      format.html do
        @search_query = query
        @search_matches = matches
        load_order_form
        render :edit
      end
    end
  end

  def add_participant
    participant = Participant.find(params[:participant_id])
    return redirect_to edit_admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    existing = participant.participant_tickets.where(invalidated_at: nil).joins(product: :order)
      .where(orders: { cancelled_at: nil }).includes(product: { order: :payments }).map(&:order).reject(&:closed?).uniq
    if existing.many?
      @payment_orders = existing
      return render "admin/participants/select_payment_order"
    elsif existing.one?
      return redirect_to admin_order_path(existing.first), notice: "This participant already has a ticket in Order ##{existing.first.id}. Review the Order."
    end
    if participant.user_id != @order.user_id
      if @order.products.where(productable_type: "ParticipantTicket").exists?
        raise ActiveRecord::RecordNotSaved, "All participant tickets must belong to the same user."
      end
      if (draft = participant.user.orders.drafts.where.not(id: @order.id).first)
        flash[:existing_draft_id] = draft.id
        return redirect_to edit_admin_order_path(@order), alert: "#{participant.user.display_name} already has draft Order ##{draft.id}. Review that Order before continuing."
      end
    end
    ActiveRecord::Base.transaction do
      @order.change_draft_owner!(participant.user) if participant.user_id != @order.user_id
      @order.with_lock do
        raise ActiveRecord::RecordNotSaved, "Only draft Orders can be edited." unless @order.editable?
        raise ActiveRecord::RecordNotSaved, "Participant cannot purchase another ticket." unless participant.can_purchase_ticket?
        participant.add_ticket_to_draft_order!
      end
    end
    redirect_to edit_admin_order_path(@order), notice: "Participant ticket added."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    redirect_to edit_admin_order_path(@order), alert: e.message
  end

  def submit
    @order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only draft Orders can be submitted." unless @order.editable?
      OrderRepricingService.call(order: @order)
      if params[:confirmed_total_cents].to_s != @order.total_cents.to_s
        return redirect_to edit_admin_order_path(@order), alert: "The Order total changed. Review the complete Order before submitting."
      end
      @order.submit!
    end
    redirect_to admin_order_path(@order), notice: "Order ##{@order.id} was submitted."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
    message = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : e.message
    redirect_to admin_order_path(@order), alert: message
  end

  def remove_product
    @order.with_lock do
      raise ActiveRecord::RecordNotSaved, "Only draft Orders can be edited." unless @order.editable?
      product = @order.products.find(params[:product_id])
      item = product.productable
      product.destroy!
      item.destroy!
    end
    redirect_to edit_admin_order_path(@order), notice: "Product removed."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  def discard
    @order.destroy!
    redirect_to admin_orders_path, notice: "Draft Order removed."
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  def show
    @order = Order.includes(:user, :products, :payments, :versions).find(params[:id])
    @products = @order.products_for_display
    @payments = @order.payments.order(created_at: :desc, id: :desc)
    @versions = @order.versions.order(created_at: :desc)
    @cancellation_versions = @versions.select { |version| version.changeset&.dig("cancelled_at")&.last.present? }
    actor_ids = @cancellation_versions.filter_map { |version| Integer(version.whodunnit, exception: false) }
    @version_actors = User.where(id: actor_ids).index_by(&:id)
  end

  def cancel
    order = @order
    order.cancel!

    redirect_to admin_orders_path, notice: "Order #{order.id} was cancelled."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to admin_orders_path, alert: "Order could not be cancelled: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def load_order_form
    @users = User.order(:email)
  end

  def order_params
    params.require(:order).permit(:user_id, participant_ids: [])
  end

  def add_selected_products!(order)
    requested_owner_id = order_params[:user_id].presence
    if requested_owner_id && requested_owner_id.to_i != order.user_id
      raise ActiveRecord::RecordNotSaved, "Order owner cannot be changed after products have been added."
    end
    participant_ids = Array(order_params[:participant_ids]).reject(&:blank?).map(&:to_i).uniq
    participants = Participant.where(id: participant_ids).to_a
    raise ActiveRecord::RecordNotSaved, "One or more selected participants could not be found." unless participants.size == participant_ids.size
    raise ActiveRecord::RecordNotSaved, "All selected participants must belong to the Order owner." if participants.any? { |participant| participant.user_id != order.user_id }
    participants.each do |participant|
      existing_orders = participant.participant_tickets.where(invalidated_at: nil).joins(product: :order).where(orders: { cancelled_at: nil }).includes(product: { order: :payments }).map(&:order).reject(&:closed?)
      if existing_orders.any? { |existing_order| existing_order.id != order.id }
        raise ActiveRecord::RecordNotSaved, "#{participant.first_name} #{participant.last_name} already has an unpaid ticket in Order ##{existing_orders.first.id}; review that Order."
      end
      raise ActiveRecord::RecordNotSaved, "#{participant.first_name} #{participant.last_name} cannot purchase a ticket." unless participant.can_purchase_ticket?
      if participant.participant_tickets.joins(product: :order).where(orders: { user_id: order.user_id, status: "draft" }).exists?
        next
      end
      ticket = participant.participant_tickets.create!
      # Ticket callbacks may attach to the user's existing draft; validate that
      # the selected Order is the one being assembled.
      product = ticket.product
      if product&.order_id != order.id
        raise ActiveRecord::RecordNotSaved, "Participant ticket was attached to a different draft Order."
      end
    end
  end

  def preload_order_display_associations(orders)
    products = orders.flat_map { |order| order.products.to_a }
    ActiveRecord::Associations::Preloader.new(records: products, associations: :productable).call

    tickets = products.filter_map { |product| product.productable if product.productable.is_a?(ParticipantTicket) }
    ActiveRecord::Associations::Preloader.new(records: tickets, associations: :participant).call if tickets.any?
  end

  def status_filter_key(order)
    return "order_cancelled" if order.cancelled?

    payments = order.payments.sort_by { |payment| [payment.created_at, payment.id] }.reverse
    return "paid" if payments.any?(&:paid?)
    return "pending" if payments.any? { |payment| !payment.unsuccessful? }
    return "awaiting" if payments.empty?

    payments.first.status
  end

  def sort_orders(orders)
    values = orders.map do |order|
      value = case @sort
      when "order_id" then order.id
      when "user" then order.user.display_name.to_s.downcase
      when "cancelled_at" then order.cancelled_at
      when "total" then order.display_total_cents
      else order.created_at
      end
      [order, value]
    end

    non_nil, nil_values = values.partition { |_order, value| value.present? }
    sorted = non_nil.sort_by { |_order, value| value }
    sorted.reverse! if @direction == :desc
    (sorted + nil_values).map(&:first)
  end
end
