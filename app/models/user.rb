# == Schema Information
#
# Table name: users
#
#  id                     :bigint           not null, primary key
#  confirmation_sent_at   :datetime
#  confirmation_token     :string
#  confirmed_at           :datetime
#  current_sign_in_at     :datetime
#  current_sign_in_ip     :string
#  email                  :string           default(""), not null
#  encrypted_password     :string           default(""), not null
#  full_name              :string
#  last_sign_in_at        :datetime
#  last_sign_in_ip        :string
#  magic_link_token       :string
#  remember_created_at    :datetime
#  reset_password_sent_at :datetime
#  reset_password_token   :string
#  role                   :string           default("regular"), not null
#  sign_in_count          :integer          default(0), not null
#  unconfirmed_email      :string
#  created_at             :datetime         not null
#  updated_at             :datetime         not null
#
# Indexes
#
#  index_users_on_confirmation_token    (confirmation_token) UNIQUE
#  index_users_on_email                 (email) UNIQUE
#  index_users_on_reset_password_token  (reset_password_token) UNIQUE
#
class User < ApplicationRecord
  devise :database_authenticatable, :magic_link_authenticatable,
         :registerable, :recoverable, :rememberable, :validatable,
         :trackable, :confirmable

  has_many :articles, dependent: :destroy
  has_many :newsletters, dependent: :restrict_with_error
  has_many :events, dependent: :destroy
  has_many :participants, dependent: :destroy
  has_many :hostel_bookings, dependent: :destroy
  has_many :orders, dependent: :destroy
  before_destroy :prepare_draft_orders_for_destruction, prepend: true

  def draft_order!
    orders.drafts.first || create_draft_order!
  end

  def prepare_draft_orders_for_destruction
    if orders.submitted.exists?
      errors.add(:base, "An account with submitted orders cannot be deleted")
      throw :abort
    end

    orders.drafts.includes(:products).each do |draft_order|
      draft_order.products.each(&:destroy!)
      draft_order.association(:products).reset
    end
  end

  validates :email, email_address: true, if: :devise_will_save_change_to_email?

  ROLES = %w[regular editor admin].freeze

  enum :role, ROLES.index_with(&:itself), validate: true, default: "regular"

  after_update :propagate_email_change, if: :saved_change_to_email?

  def after_confirmation
    super
    NewsletterSubscription.subscribe_user(self)
  end

  def self.confirm_by_token(token)
    return super if token.blank?

    transaction do
      digest = Devise.token_generator.digest(self, :confirmation_token, token)
      where(confirmation_token: [token, digest]).lock.load
      super
    end
  end

  # Each resend gets its own two-week lifetime and invalidates older links.
  def resend_confirmation_instructions
    self.confirmation_token = nil
    @raw_confirmation_token = nil
    super
  end

  # Invalidate the magic link after a successful sign-in so each link works
  # exactly once. See MagicLink::SingleUseTokenizer.
  def after_magic_link_authentication
    update_column(:magic_link_token, nil) if magic_link_token.present?
  end

  scope :ordered_by_name, -> { order(full_name: :asc) }

  def display_name
    full_name.presence || email
  end

  def can_create?
    editor? || admin?
  end

  def can_edit?
    editor? || admin?
  end

  def can_delete?
    admin?
  end

  def account_deletable?
    regular? && articles.none? && events.none? && !orders.submitted.exists? && !hostel_bookings.joins(:payments).exists?
  end

  def password_set?
    encrypted_password.present?
  end

  # Allow users to be created without a password when explicitly created via
  # the passwordless flow (e.g. auto-created on participant registration).
  # Regular Devise registrations still require a password.
  attr_accessor :skip_password_validation

  attr_writer :registration_participant

  def registration_participant
    @registration_participant || participants.order(created_at: :asc, id: :asc).first
  end

  def password_required?
    return false if skip_password_validation && password.blank?

    !persisted? || !password.nil? || !password_confirmation.nil?
  end

  private

  def create_draft_order!
    Order.transaction(requires_new: true) { orders.create!(status: "draft") }
  rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
    orders.drafts.first || raise
  end

  def propagate_email_change
    old_email, new_email = saved_change_to_email
    normalized_email = NewsletterSubscription.normalize_email(new_email)

    participants.update_all(email: normalized_email, updated_at: Time.current)
    NewsletterSubscription.update_email(old_email, normalized_email) if participants.exists?
  end
end
