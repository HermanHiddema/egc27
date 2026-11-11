# == Schema Information
#
# Table name: orders
#
#  id         :bigint           not null, primary key
#  status     :string           default("submitted"), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  user_id    :bigint           not null
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

  validates :status, inclusion: { in: %w[draft submitted] }
  validate :draft_is_unique_for_user, if: :draft?
  validate :submitted_order_has_products, if: :submitted?
  validate :draft_cannot_have_payments, if: :draft?
  validate :lifecycle_changes_are_valid, on: :update
  before_destroy :prepare_draft_for_destruction, prepend: true

  scope :drafts, -> { where(status: "draft") }
  scope :submitted, -> { where(status: "submitted") }

  def draft?
    status == "draft"
  end

  def submitted?
    status == "submitted"
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

  alias amount_cents total_cents

  def closed?
    payments.completed.exists?
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
