# == Schema Information
#
# Table name: participants
#
#  id                            :bigint           not null, primary key
#  accepted_privacy_policy       :boolean          default(FALSE), not null
#  accepted_terms_and_conditions :boolean          default(FALSE), not null
#  age_group                     :string           not null
#  club                          :string           not null
#  country                       :string           not null
#  egd_pin                       :string
#  email                         :string           not null
#  first_name                    :string           not null
#  first_week                    :boolean          default(TRUE)
#  gender                        :string
#  image_use_consent             :boolean          default(FALSE), not null
#  last_name                     :string           not null
#  participant_type              :string           default("player"), not null
#  phone                         :string
#  rank                          :integer
#  rating                        :integer
#  second_week                   :boolean          default(TRUE)
#  uuid                          :uuid             not null
#  weekend                       :boolean          default(TRUE)
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  user_id                       :bigint           not null
#
# Indexes
#
#  index_participants_on_created_at        (created_at)
#  index_participants_on_egd_pin           (egd_pin) UNIQUE
#  index_participants_on_email             (email)
#  index_participants_on_gender            (gender)
#  index_participants_on_participant_type  (participant_type)
#  index_participants_on_phone             (phone)
#  index_participants_on_rating            (rating)
#  index_participants_on_user_id           (user_id)
#  index_participants_on_uuid              (uuid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class Participant < ApplicationRecord
  PARTICIPANT_TYPES = %w[player visitor].freeze
  GENDERS = %w[male female non_binary prefer_not_to_say].freeze
  AGE_GROUPS = %w[0-11 12-17 18-49 50+].freeze
  ATTENDANCE_OPTIONS = {
    "all_events" => { first_week: true, weekend: true, second_week: true },
    "first_week_plus_weekend" => { first_week: true, weekend: true, second_week: false },
    "weekend_plus_second_week" => { first_week: false, weekend: true, second_week: true },
    "weekend_only" => { first_week: false, weekend: true, second_week: false }
  }.freeze

  MIN_RATING = -1000
  MAX_RATING = 3000

  has_paper_trail

  has_many :event_registrations, dependent: :destroy
  has_many :events, through: :event_registrations
  has_many :participant_tickets, inverse_of: :participant, dependent: :destroy, autosave: true
  has_many :products, through: :participant_tickets
  has_many :orders, through: :products
  has_many :payments, through: :orders
  # The user is always derived from the email during registration, so a missing
  # user can only result from a missing email. The association is marked optional
  # here only to suppress the framework's "User must exist" error; user presence
  # is instead validated conditionally below so that a missing email surfaces as
  # the single root-cause error. The participants.user_id NOT NULL database
  # constraint remains the backend safety net guaranteeing a user is always set.
  belongs_to :user, optional: true

  attribute :image_use_consent, :boolean, default: nil
  attr_accessor :attendance_option

  # Participants whose payment was refunded or charged back are no longer
  # attending, so they are left out of the public participant list. A later
  # successful payment reinstates them.
  scope :confirmed, -> { joins(:user).where.not(users: { confirmed_at: nil }) }

  scope :not_refunded, -> {
    paid_ids = ParticipantTicket.joins(product: { order: :payments }).merge(Payment.completed.unreversed).select(:participant_id)
    reversed_ids = ParticipantTicket.joins(product: { order: :payments }).merge(Payment.reversed).select(:participant_id)
    where.not(id: reversed_ids).or(where(id: paid_ids))
  }

  validates :first_name, :last_name, :email, :country, presence: true
  validates :user, presence: true, if: -> { email.present? }
  validates :age_group, inclusion: { in: AGE_GROUPS, message: "must be selected" }
  validates :participant_type, inclusion: { in: PARTICIPANT_TYPES, message: "must be selected" }
  validates :gender, inclusion: { in: GENDERS, message: "must be selected" }
  validates :accepted_terms_and_conditions, inclusion: { in: [true], message: "must be accepted" }
  validates :accepted_privacy_policy, inclusion: { in: [true], message: "must be accepted" }
  validates :image_use_consent, inclusion: { in: [true, false], message: "must be selected" }
  validates :attendance_option, inclusion: { in: ATTENDANCE_OPTIONS.keys, message: "must be selected" }, allow_blank: true
  validates :email, email_address: true
  validates :phone, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid international phone number" }, allow_blank: true
  validates :country, format: { with: /\A[A-Z]{2}\z/, message: "must be an ISO 3166-1 alpha-2 code" }
  validates :rating, numericality: {
    only_integer: true,
    greater_than_or_equal_to: MIN_RATING,
    less_than_or_equal_to: MAX_RATING
  }, allow_nil: true
  validates :egd_pin, format: { with: /\A\d{8}\z/, message: "must be an 8 digit number" },
                      uniqueness: { message: "is already registered" }, allow_blank: true
  validates :rank, numericality: {
    only_integer: true,
    greater_than_or_equal_to: EgdGradeMapping::MIN_GRADE_N,
    less_than_or_equal_to: EgdGradeMapping::MAX_GRADE_N
  }, allow_nil: true

  before_validation :normalize_text_fields
  before_validation :normalize_participant_type
  before_validation :ensure_participant_ticket
  before_validation :normalize_gender
  before_validation :normalize_rank
  before_validation :normalize_rating
  before_validation :set_implicit_policy_acceptance
  before_validation :apply_attendance_option
  after_commit :reprice_open_ticket_order, on: [:create, :update], if: :pricing_inputs_changed?

  after_commit :sync_from_egd, on: [:create, :update], if: -> { saved_change_to_egd_pin? && egd_pin.present? }

  def ticket
    current_ticket || participant_tickets.joins(:product).order(created_at: :desc).first ||
      participant_tickets.detect(&:new_record?) || (participant_tickets.build if player?)
  end

  def current_ticket
    draft_ticket || participant_tickets.detect(&:valid_admission?) || in_progress_ticket || retryable_ticket
  end

  def participant_ticket
    ticket
  end

  def product
    participant_ticket&.product
  end

  def order
    product&.order
  end

  def current_order
    current_ticket&.product&.order
  end

  def can_purchase_ticket?
    return false unless player?
    return false if valid_admission?
    return false if participant_tickets.joins(product: { order: :payments }).merge(Payment.pending_or_open).exists?

    true
  end

  def valid_admission?
    participant_tickets.any?(&:valid_admission?)
  end

  def draft_ticket
    participant_tickets.joins(product: :order).where(orders: { status: "draft" }).order(created_at: :desc).first
  end

  def retryable_ticket
    participant_tickets.joins(product: :order).where(orders: { status: "submitted" })
      .order(created_at: :desc).detect do |ticket|
        !ticket.order.closed? && !ticket.order.payments.blocking.exists?
      end
  end

  def in_progress_ticket
    participant_tickets.joins(product: { order: :payments }).merge(Payment.pending_or_open)
      .where(orders: { status: "submitted" }).order(created_at: :desc).first
  end

  def add_ticket_to_draft_order!
    existing = participant_tickets.joins(:product).where(products: { order_id: user.draft_order!.id }).first
    return existing if existing
    raise ActiveRecord::RecordNotSaved, "Participant cannot purchase another ticket" unless can_purchase_ticket?

    participant_tickets.create!
  end

  def to_param
    uuid
  end

  # A short, memorable participant number shown to participants and admins.
  # Derived from the database id with a fixed offset so the smallest numbers
  # are still comfortably large.
  PARTICIPANT_NUMBER_OFFSET = 1000

  def participant_number
    return unless id

    id + PARTICIPANT_NUMBER_OFFSET
  end

  def confirmed?
    user&.confirmed? || false
  end

  def player?
    participant_type == "player"
  end

  # A participant is considered paid once any of their payments has completed.
  # Uses the in-memory association when it is already loaded (e.g. eager loaded
  # in the admin list) to avoid an extra query per participant.
  def paid?
    if payments.loaded?
      payments.any?(&:paid?)
    else
      payments.completed.exists?
    end
  end

  # A participant is considered refunded when a payment has a refund and no
  # other paid payment is without a refund or chargeback.
  def refunded?
    return false if registration_paid?

    if payments.loaded?
      payments.any?(&:refunded?)
    else
      payments.refunded.exists?
    end
  end

  # Chargebacks use the same registration status precedence as refunds.
  def charged_back?
    return false if registration_paid?

    if payments.loaded?
      payments.any?(&:charged_back?)
    else
      payments.charged_back.exists?
    end
  end

  # The most recent payment that completed successfully, if any.
  def paid_payment
    payments.completed.order(created_at: :desc).first
  end

  # The most recent payment that is still in progress at the provider, if any.
  def pending_payment
    payments.pending_or_open.order(created_at: :desc).first
  end

  # The payment to show on the payment page comes from the currently selected
  # ticket's Order, so a historical paid Order does not hide a replacement.
  def current_payment
    selected_order = current_order
    return unless selected_order

    selected_order.payments.completed.order(created_at: :desc, id: :desc).first ||
      selected_order.payments.pending_or_open.order(created_at: :desc, id: :desc).first ||
      Payment.build_for(self)
  end

  # Refresh refund and chargeback amounts without changing the paid status.
  def refresh_paid_payments!
    payment = payments.completed.where.not(mollie_payment_id: [nil, ""]).order(created_at: :desc).first
    payment&.refresh_from_mollie!

    association(:payments).reset
  rescue Mollie::Exception => e
    Rails.logger.error "[Mollie] Error refreshing paid payments for participant #{id}: #{e.message}"
  end

  # Payments that are canceled, expired or failed can never succeed
  # anymore, so they do not block recording a manual payment. Uses the in-memory
  # association when it is already loaded, like #paid?.
  def blocking_payments?
    if payments.loaded?
      payments.any? { |payment| !payment.unsuccessful? }
    else
      payments.blocking.exists?
    end
  end

  # Admins may only delete participants with no current paid, charged-back or
  # refunded payment status and no open/pending payment. A payment that is still in
  # flight at a provider (e.g. Mollie) could complete after the participant
  # and its payment records are gone, leaving the app with money received but
  # nothing to reconcile it against, so deletion is blocked until that payment
  # resolves.
  def deletable?
    !charged_back? && !refunded? && !blocking_payments? && !submitted_ticket_order?
  end

  def submitted_ticket_order?
    participant_tickets.joins(product: :order).where(orders: { status: "submitted" }).exists?
  end

  # Deleting the last participant of a user leaves an account behind that no
  # longer has a registration, so admins are warned about that case.
  def only_participant_for_user?
    return false if user.blank?

    user.participants.where.not(id: id).none?
  end

  # High-level registration status used in the admin participant list.
  def registration_status
    return "Paid" if registration_paid?
    return "Chargeback" if charged_back?
    return "Refund" if refunded?
    return "Confirmed" if confirmed?

    "Pending"
  end

  def visitor?
    participant_type == "visitor"
  end

  def rank_grade
    EgdGradeMapping.grade_for(rank)
  end

  def attendance_option
    return @attendance_option if @attendance_option.present?

    case [first_week, weekend, second_week]
    when [true, true, true] then "all_events"
    when [true, true, false] then "first_week_plus_weekend"
    when [false, true, true] then "weekend_plus_second_week"
    when [false, true, false] then "weekend_only"
    end
  end

  private

  def registration_paid?
    if payments.loaded?
      payments.any? { |payment| payment.paid? && !payment.refunded? && !payment.charged_back? }
    else
      payments.completed.unreversed.exists?
    end
  end

  def reprice_open_ticket_order
    return unless player? && order

    OrderRepricingService.call(order: order, date: Date.current)
  end

  def pricing_inputs_changed?
    saved_change_to_participant_type? || saved_change_to_age_group? || saved_change_to_first_week? ||
      saved_change_to_weekend? || saved_change_to_second_week?
  end

  def ensure_participant_ticket
    participant_tickets.build if player? && participant_tickets.empty?
  end

  # Refreshes rank and rating from the European Go Database for the new pin.
  def sync_from_egd
    EgdSyncJob.perform_later(id)
  end

  def normalize_text_fields
    self.first_name = first_name.to_s.strip
    self.last_name = last_name.to_s.strip
    self.email = email.to_s.strip.downcase.presence
    self.country = country.to_s.strip.upcase
    self.phone = normalize_phone(phone)
    self.club = club.to_s.strip
    self.egd_pin = egd_pin.to_s.strip.presence
  end

  def normalize_participant_type
    self.participant_type = participant_type.to_s.strip.downcase.presence || "player"
  end

  def normalize_gender
    raw = gender.to_s.strip.downcase.presence
    return if raw.blank?

    # Convert display format (with spaces and hyphens) to underscore format
    normalized = raw.gsub(/[\s-]+/, "_")
    self.gender = normalized if GENDERS.include?(normalized)
  end

  def normalize_rank
    source_value = if respond_to?(:rank_before_type_cast)
      rank_before_type_cast
    else
      rank
    end

    self.rank = EgdGradeMapping.grade_n_for(source_value)
  end

  # The rating is derived, never set directly by participants. An EGD pin that
  # has resulted in a rating takes priority; otherwise the entered rank is
  # converted to a rating. Runs after normalize_rank so the rank is already a
  # grade_n integer.
  def normalize_rating
    derived = egd_sourced_rating || EgdGradeMapping.rating_for(rank)
    self.rating = clamp_rating(derived)
  end

  # A rating that originates from an EGD pin lookup. Only trusted when an EGD
  # pin is present, so a submitted rating can never override the rank-derived
  # value on its own.
  def egd_sourced_rating
    return nil if egd_pin.blank?

    normalize_integer(rating)
  end

  def clamp_rating(value)
    return nil if value.nil?

    value.clamp(MIN_RATING, MAX_RATING)
  end

  def normalize_integer(value)
    return nil if value.blank?

    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end

  def normalize_phone(value)
    raw = value.to_s.strip
    return nil if raw.blank?

    digits = raw.gsub(/\D/, "")
    return nil if digits.blank?

    "+#{digits}"
  end

  def set_implicit_policy_acceptance
    self.accepted_terms_and_conditions = true
    self.accepted_privacy_policy = true
  end

  def apply_attendance_option
    option = attendance_option.to_s
    return if option.blank?

    selection = ATTENDANCE_OPTIONS[option]
    return unless selection

    self.first_week = selection[:first_week]
    self.weekend = selection[:weekend]
    self.second_week = selection[:second_week]
  end
end
