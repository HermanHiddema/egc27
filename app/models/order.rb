# == Schema Information
#
# Table name: orders
#
#  id           :bigint           not null, primary key
#  cancelled_at :datetime
#  status       :string           default("submitted"), not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  user_id      :bigint           not null
#
# Indexes
#
#  index_orders_on_user_id          (user_id)
#  index_orders_one_draft_per_user  (user_id) UNIQUE WHERE ((status)::text = 'draft'::text)
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Order < ApplicationRecord
  belongs_to :user
  has_many :products, dependent: :restrict_with_error, inverse_of: :order
  has_many :payments, dependent: :restrict_with_error
  has_paper_trail

  validates :status, inclusion: { in: %w[draft submitted] }
  validate :draft_is_unique_for_user, if: :draft?
  validate :submitted_order_has_products, if: :submitted?
  validate :draft_cannot_have_payments, if: :draft?
  validate :lifecycle_changes_are_valid, on: :update
  validate :cancellation_changes_are_valid, if: :will_save_change_to_cancelled_at?
  before_destroy :prepare_draft_for_destruction, prepend: true

  scope :drafts, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }

  def draft?
    status == "draft"
  end

  def submitted?
    status == "submitted"
  end

  def cancelled?
    cancelled_at.present?
  end

  def editable?
    draft? && payments.none?
  end

  def add_product_to_draft!(productable)
    with_lock do
      reload
      products.create!(productable: productable)
    end
  end

  def submit!
    with_lock do
      if products.empty?
        errors.add(:products, "must include at least one product")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      products.includes(:productable).each do |product|
        unless product.valid?
          errors.add(:base, "A product is invalid: #{product.errors.full_messages.to_sentence}")
          raise ActiveRecord::RecordInvalid.new(self)
        end

        next unless product.productable.is_a?(ParticipantTicket)
        unless product.productable.participant.can_purchase_ticket?
          errors.add(:base, "A participant can no longer purchase this ticket")
          raise ActiveRecord::RecordInvalid.new(self)
        end
      end

      OrderRepricingService.call(order: self, date: Date.current)
      @submitting = true
      update!(status: "submitted")
    ensure
      @submitting = false
    end
  end

  def total_cents
    Product.where(order_id: id).sum(:price_cents)
  end

  def display_total_cents
    return products.to_a.sum { |product| product.price_cents.to_i } if association(:products).loaded?

    total_cents
  end

  def products_for_display
    product_records = products.to_a
    if product_records.any? { |product| !product.association(:productable).loaded? }
      ActiveRecord::Associations::Preloader.new(records: product_records, associations: :productable).call
    end
    product_records.sort_by do |product|
      type_order = product.productable.is_a?(ParticipantTicket) ? 0 : 1
      [type_order, product.created_at, product.id]
    end
  end

  def cancellable?
    return false unless submitted? && !cancelled?

    if association(:payments).loaded?
      payments.none?(&:paid?) && payments.none? { |payment| payment.status.in?(%w[open pending authorized]) }
    else
      !payments.completed.exists? && !payments.pending_or_open.exists?
    end
  end

  def cancel!
    with_lock do
      reload
      unless cancellable?
        errors.add(:base, "This order cannot be cancelled because it is paid, has a payment in progress, or is already cancelled.")
        raise ActiveRecord::RecordInvalid.new(self)
      end

      products.includes(:productable).each do |product|
        ticket = product.productable
        ticket.invalidate_admission! if ticket.is_a?(ParticipantTicket) && ticket.invalidated_at.nil?
      end

      @cancelling = true
      begin
        update!(cancelled_at: Time.current)
      ensure
        @cancelling = false
      end
    end
  end

  alias amount_cents total_cents

  def closed?
    cancelled? || payments.completed.exists?
  end

  # Open Mollie checkouts can be resumed; other active payments must finish first.
  def payment_action
    if association(:payments).loaded?
      payment_records = payments.to_a
      return :closed if cancelled? || payment_records.any?(&:paid?)
      return :pending if payment_records.any? { |payment| payment.status.in?(%w[pending authorized]) || (payment.status == "open" && payment.provider != "mollie") }
      return :resume if payment_records.any? { |payment| payment.status == "open" && payment.provider == "mollie" }

      return payment_records.any? ? :retry : :pay
    end

    return :closed if closed?
    return :pending if payments.where(status: %w[pending authorized]).exists? || payments.where(status: "open").where.not(provider: "mollie").exists?
    return :resume if payments.where(status: "open", provider: "mollie").exists?

    payments.exists? ? :retry : :pay
  end

  private

  def draft_is_unique_for_user
    return unless self.class.drafts.where(user_id: user_id).where.not(id: id).exists?

    errors.add(:user, "already has a draft order")
  end

  def submitted_order_has_products
    errors.add(:products, "must include at least one product") if products.empty?
  end

  def draft_cannot_have_payments
    errors.add(:payments, "cannot be added to a draft order") if payments.exists?
  end

  def lifecycle_changes_are_valid
    return unless will_save_change_to_status?

    old_status, new_status = status_change_to_be_saved
    return if old_status == "draft" && new_status == "submitted" && @submitting

    errors.add(:status, "can only change through order submission")
  end

  def cancellation_changes_are_valid
    valid_cancellation = @cancelling && cancelled_at.present? && cancelled_at_in_database.nil? && submitted? &&
      !payments.completed.exists? && !payments.pending_or_open.exists?
    return if valid_cancellation

    errors.add(:cancelled_at, "can only be set through the cancellation action on an unpaid order")
  end

  def prepare_draft_for_destruction
    if draft? && payments.empty?
      products.reload.each do |product|
        productable = product.productable
        product.destroy!
        productable.destroy! if productable.is_a?(ParticipantTicket) || productable.is_a?(HostelBooking)
      end
      products.reset
      return
    end

    errors.add(:base, "submitted orders and their financial history cannot be deleted")
    throw :abort
  end
end
