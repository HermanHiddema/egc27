# == Schema Information
#
# Table name: payments
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  confirmation_sent :boolean          default(FALSE), not null
#  description       :string           not null
#  status            :string           default("open"), not null
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  mollie_payment_id :string
#  participant_id    :bigint           not null
#
# Indexes
#
#  index_payments_on_mollie_payment_id  (mollie_payment_id) UNIQUE
#  index_payments_on_participant_id     (participant_id)
#  index_payments_on_status             (status)
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class Payment < ApplicationRecord
  STATUSES = %w[open canceled pending authorized expired failed paid].freeze

  belongs_to :participant

  validates :status, inclusion: { in: STATUSES }
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :description, presence: true
  validates :mollie_payment_id, uniqueness: true, allow_nil: true

  scope :completed, -> { where(status: "paid") }
  scope :pending_or_open, -> { where(status: %w[open pending authorized]) }

  after_update_commit :send_payment_confirmation, if: :became_paid?

  def paid?
    status == "paid"
  end

  def amount_eur
    amount_cents / 100.0
  end

  def amount_formatted
    "€ #{format('%.2f', amount_eur)}"
  end

  private

  def became_paid?
    saved_change_to_status? && paid?
  end

  def send_payment_confirmation
    return if participant.email.blank?

    # Atomic check-and-set prevents duplicate emails under concurrent webhook/redirect updates.
    return unless Payment.where(id: id, confirmation_sent: false).update_all(confirmation_sent: true) == 1

    ParticipantMailer.payment_confirmation(self).deliver_later
  end
end
