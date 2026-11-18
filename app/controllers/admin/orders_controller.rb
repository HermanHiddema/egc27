class Admin::OrdersController < ApplicationController
  SORT_COLUMNS = %w[order_id submitted user cancelled_at total].freeze
  STATUS_FILTERS = %w[awaiting pending paid failed canceled expired order_cancelled].freeze

  before_action :require_admin!
  before_action :set_order, only: [:show, :edit, :update, :submit, :cancel, :remove_product, :discard, :participants, :add_participant, :new_participant, :empty]
  before_action :set_return_order, only: [:show, :cancel, :discard]

  def index
    @draft_orders = Order.drafts.includes(:user, :products, :payments).order(created_at: :desc)
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
    @order = Order.new(user: current_user, status: "draft")
    if (draft = current_user.orders.drafts.first)
      flash.now[:existing_draft_id] = draft.id
      flash.now[:alert] = draft_conflict_message(current_user)
    end
    load_order_form
    render :edit
  end

  def owners
    query = params[:q].to_s.strip
    prefix = "#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    users = User.where("full_name ILIKE :prefix OR email ILIKE :prefix", prefix: prefix).order(:email).limit(10)
    render json: users.map { |user| { id: user.id, label: "#{user.display_name} (#{user.email})" } }
  end

  def create
    owner = User.find(order_params[:user_id].presence || current_user.id)
    owner.with_lock do
      if (draft = owner.orders.drafts.first)
        @order = Order.new(user: owner, status: "draft")
        flash.now[:existing_draft_id] = draft.id
        flash.now[:alert] = draft_conflict_message(owner)
        load_order_form
        return render :edit, status: :unprocessable_entity
      end
      @order = owner.orders.create!(status: "draft")
    end
    destination = case params[:next_step]
    when "participant" then new_participant_admin_order_path(@order)
    when "hostel" then new_admin_order_hostel_booking_path(@order)
    else edit_admin_order_path(@order)
    end
    redirect_to destination
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique => e
    @order = Order.new(user: owner, status: "draft")
    if (draft = owner.orders.drafts.first)
      flash.now[:existing_draft_id] = draft.id
      flash.now[:alert] = draft_conflict_message(owner)
    else
      message = e.is_a?(ActiveRecord::RecordInvalid) ? e.record.errors.full_messages.to_sentence : "The draft Order could not be created. Please try again."
      @order.errors.add(:base, message)
    end
    load_order_form
    render :edit, status: :unprocessable_entity
  end

  def edit
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    load_order_form
  end

  def update
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    @new_owner = User.find(order_params.fetch(:user_id))
    return redirect_to edit_admin_order_path(@order) if @new_owner.id == @order.user_id

    if (draft = @new_owner.orders.drafts.where.not(id: @order.id).first)
      flash[:existing_draft_id] = draft.id
      return redirect_to edit_admin_order_path(@order), alert: draft_conflict_message(@new_owner)
    end
    @selected_participant = @new_owner.participants.find(owner_change_params[:participant_id]) if owner_change_params[:participant_id].present?
    @order.with_lock do
      if (@order.products.exists? || @selected_participant) && !@order.owner_change_confirmed?(@new_owner, owner_change_params[:owner_change_token])
        return render :confirm_owner_change, status: :unprocessable_entity
      end
      @order.change_draft_owner!(@new_owner, clear_products: true)
      @order.add_participant_ticket!(@selected_participant) if @selected_participant
    end
    redirect_to edit_admin_order_path(@order), notice: "Order owner updated. Review the basket before submission."
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved, ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotUnique => e
    @order.reload
    flash.now[:existing_draft_id] = @new_owner.orders.drafts.where.not(id: @order.id).pick(:id) if @new_owner
    if flash[:existing_draft_id]
      flash.now[:alert] = draft_conflict_message(@new_owner)
    else
      @order.errors.add(:base, e.is_a?(ActiveRecord::RecordNotUnique) ? "The owner could not be changed. Please try again." : e.message)
    end
    load_order_form
    render :edit, status: :unprocessable_entity
  end

  def participants
    return head :not_found unless @order.editable?

    query = params[:q].to_s.strip
    prefix = "#{ActiveRecord::Base.sanitize_sql_like(query)}%"
    paid_participant_ids = ParticipantTicket.eligible_for_registration_status.joins(product: { order: :payments })
      .merge(Payment.completed).select(:participant_id)
    basket_participant_ids = ParticipantTicket.joins(:product).where(products: { order_id: @order.id }).select(:participant_id)
    scope = Participant.includes(:user).where(participant_type: "player")
      .where.not(id: paid_participant_ids)
      .where.not(id: basket_participant_ids)
      .where("first_name ILIKE :prefix OR last_name ILIKE :prefix OR CONCAT_WS(' ', first_name, last_name) ILIKE :prefix", prefix: prefix)
    scope = scope.where(user_id: @order.user_id) unless @order.user.admin?
    matches = scope.order(:last_name, :first_name, :id).limit(10).map do |participant|
      { id: participant.id, label: "#{participant.first_name} #{participant.last_name} · #{participant.user.email}" }
    end
    render json: matches
  end

  def new_participant
    return redirect_to admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?

    @admin_basket = true
    render "orders/new_participant"
  end

  def add_participant
    participant = Participant.find(params.permit(:participant_id).require(:participant_id))
    @order.with_lock do
      return redirect_to edit_admin_order_path(@order), alert: "Only draft Orders can be edited." unless @order.editable?
      if participant.user_id != @order.user_id && !@order.user.admin?
        raise ActiveRecord::RecordNotSaved, "All participant tickets must belong to the Order owner. Change the owner first."
      end
      if participant.participant_tickets.joins(:product).where(products: { order_id: @order.id }).exists?
        return redirect_to new_participant_admin_order_path(@order), notice: "This participant already has a ticket in this shopping basket."
      end
      raise ActiveRecord::RecordNotSaved, "Participant cannot purchase another ticket." if !participant.player? || participant.valid_admission?

      existing = participant.participant_tickets.where(invalidated_at: nil).joins(product: :order)
        .where(orders: { cancelled_at: nil }).includes(product: { order: :payments }).map(&:order).reject(&:closed?).uniq
      if existing.any?
        flash[:unpaid_order_ids] = existing.map(&:id)
        flash[:unpaid_order_return_id] = @order.id
        message = existing.one? ? "This participant already has a ticket in an order. Pay or cancel that order before purchasing another ticket." : "This participant already has tickets in unpaid orders. Pay or cancel those orders before purchasing another ticket."
        return redirect_to new_participant_admin_order_path(@order), alert: message
      end
      if participant.user_id != @order.user_id
        @new_owner = participant.user
        @selected_participant = participant
        return render :confirm_owner_change, status: :unprocessable_entity
      end
      @order.add_participant_ticket!(participant)
      redirect_to edit_admin_order_path(@order), notice: "Participant ticket added."
    end
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
    @order.remove_basket_product!(params[:product_id])
    redirect_to edit_admin_order_path(@order), notice: "Product removed."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  def empty
    @order.empty_basket!
    redirect_to edit_admin_order_path(@order), notice: "Your shopping basket is empty."
  rescue ActiveRecord::RecordNotDestroyed, ActiveRecord::RecordNotSaved => e
    redirect_to admin_order_path(@order), alert: e.message
  end

  def discard
    @order.with_lock { @order.destroy! }
    destination = @return_order ? new_participant_admin_order_path(@return_order) : admin_orders_path
    redirect_to destination, notice: "Draft Order deleted.", status: :see_other
  rescue ActiveRecord::RecordNotDestroyed => e
    redirect_to admin_order_path(@order, return_order_id: @return_order&.id), alert: e.message
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

    destination = @return_order ? new_participant_admin_order_path(@return_order) : admin_orders_path
    redirect_to destination, notice: "Order #{order.id} was cancelled.", status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    destination = @return_order ? admin_order_path(@order, return_order_id: @return_order.id) : admin_orders_path
    redirect_to destination, alert: "Order could not be cancelled: #{e.record.errors.full_messages.to_sentence}", status: :see_other
  end

  private

  def set_order
    @order = Order.find(params[:id])
  end

  def set_return_order
    return_id = params.permit(:return_order_id)[:return_order_id]
    return if return_id.blank?

    @return_order = Order.drafts.where.not(id: @order.id).find_by(id: return_id)
    @return_order = nil unless @return_order&.editable?
  end

  def load_order_form
    @admin_basket = true
    @products = @order.persisted? ? @order.products_for_display : []
  end

  def order_params
    params.fetch(:order, ActionController::Parameters.new).permit(:user_id)
  end

  def owner_change_params
    params.permit(:participant_id, :owner_change_token)
  end

  def draft_conflict_message(owner)
    "#{owner.display_name} already has a draft order. This order needs to be completed before a new order in their name can be processed."
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
