# == Schema Information
#
# Table name: payments
#
#  id                :bigint           not null, primary key
#  amount_cents      :integer          not null
#  confirmation_sent :boolean          default(FALSE), not null
#  description       :string           not null
#  payment_method    :string
#  provider          :string           default("mollie"), not null
#  reference         :string
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
#  index_payments_on_provider           (provider)
#  index_payments_on_status             (status)
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class Payment < ApplicationRecord
  STATUSES = %w[open canceled pending authorized expired failed paid].freeze
  # Payments are normally handled by Mollie, but admins can also record payments
  # that were received outside of Mollie (e.g. cash or bank transfer).
  PROVIDERS = %w[mollie manual].freeze
  # The method used to pay. Mollie reports its own methods (ideal, creditcard,
  # …), so only the methods available for manually recorded payments are listed.
  # "pointofsale" covers card payments taken in person at the congress desk.
  MANUAL_PAYMENT_METHODS = %w[cash pointofsale bank_transfer other].freeze
  # Labels for methods that do not read well when humanized.
  PAYMENT_METHOD_LABELS = { "pointofsale" => "Point of sale" }.freeze

  belongs_to :participant

  validates :status, inclusion: { in: STATUSES }
  validates :provider, inclusion: { in: PROVIDERS }
  validates :payment_method, inclusion: { in: MANUAL_PAYMENT_METHODS }, if: :manual?
  validates :amount_cents, numericality: { only_integer: true, greater_than: 0 }
  validates :description, presence: true
  validates :mollie_payment_id, uniqueness: true, allow_nil: true

  scope :completed, -> { where(status: "paid") }
  scope :pending_or_open, -> { where(status: %w[open pending authorized]) }
  scope :manual, -> { where(provider: "manual") }

  # Payments recorded manually by an admin can be created directly as paid, so
  # confirmations are sent both on create and on update.
  after_commit :send_payment_confirmation, on: [:create, :update], if: :became_paid?

  def self.payment_method_label(payment_method)
    return if payment_method.blank?

    PAYMENT_METHOD_LABELS.fetch(payment_method) { payment_method.humanize }
  end

  def paid?
    status == "paid"
  end

  def manual?
    provider == "manual"
  end

  def provider_label
    provider.humanize
  end

  def payment_method_label
    self.class.payment_method_label(payment_method)
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

    ParticipantMailer.payment_confirmation(self).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to deliver payment confirmation for Payment #{id}: #{e.class}: #{e.message}")
  end
end
