class Participant < ApplicationRecord
  PARTICIPANT_TYPES = %w[player visitor].freeze
  GENDERS = %w[male female non_binary prefer_not_to_say].freeze
  ATTENDANCE_OPTIONS = {
    "all_events" => { first_week: true, weekend: true, second_week: true },
    "first_week_plus_weekend" => { first_week: true, weekend: true, second_week: false },
    "weekend_plus_second_week" => { first_week: false, weekend: true, second_week: true },
    "weekend_only" => { first_week: false, weekend: true, second_week: false }
  }.freeze

  has_many :event_registrations, dependent: :destroy
  has_many :events, through: :event_registrations
  has_many :payments, dependent: :destroy
  belongs_to :user, optional: true

  attribute :image_use_consent, :boolean, default: nil
  attr_accessor :attendance_option

  validates :first_name, :last_name, :email, :date_of_birth, :country, presence: true
  validates :participant_type, inclusion: { in: PARTICIPANT_TYPES }
  validates :gender, inclusion: { in: GENDERS }
  validates :accepted_terms_and_conditions, inclusion: { in: [true], message: "must be accepted" }
  validates :accepted_privacy_policy, inclusion: { in: [true], message: "must be accepted" }
  validates :image_use_consent, inclusion: { in: [true, false] }
  validates :attendance_option, inclusion: { in: ATTENDANCE_OPTIONS.keys }, allow_blank: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :phone, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid international phone number" }, allow_blank: true
  validates :country, format: { with: /\A[A-Z]{2}\z/, message: "must be an ISO 3166-1 alpha-2 code" }
  validates :rating, numericality: { only_integer: true }, allow_nil: true
  validates :rank, numericality: {
    only_integer: true,
    greater_than_or_equal_to: EgdGradeMapping::MIN_GRADE_N,
    less_than_or_equal_to: EgdGradeMapping::MAX_GRADE_N
  }, allow_nil: true

  before_validation :normalize_text_fields
  before_validation :normalize_participant_type
  before_validation :normalize_gender
  before_validation :normalize_date_of_birth
  before_validation :normalize_rank
  before_validation :normalize_rating
  before_validation :set_implicit_policy_acceptance
  before_validation :apply_attendance_option

  def confirmed?
    confirmed_at.present?
  end

  def player?
    participant_type == "player"
  end

  def visitor?
    participant_type == "visitor"
  end

  def generate_confirmation_token!
    update_column(:confirmation_token, SecureRandom.urlsafe_base64(32))
  end

  def confirm!
    update_columns(confirmed_at: Time.current, confirmation_token: nil)
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

  def normalize_date_of_birth
    self.date_of_birth = parse_date(date_of_birth)
  end

  def normalize_rating
    self.rating = normalize_integer(rating)
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

  def parse_date(value)
    return value if value.is_a?(Date)

    raw = value.to_s.strip
    return nil if raw.blank?

    Date.strptime(raw, "%d-%m-%Y")
  rescue ArgumentError
    Date.parse(raw)
  rescue TypeError
    nil
  end
end
