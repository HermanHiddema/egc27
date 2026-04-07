class Participant < ApplicationRecord
  PARTICIPANT_TYPES = %w[player visitor].freeze
  GENDERS = %w[male female non_binary prefer_not_to_say].freeze

  has_many :event_registrations, dependent: :destroy
  has_many :events, through: :event_registrations
  belongs_to :user, optional: true

  validates :first_name, :last_name, :email, :date_of_birth, :country, presence: true
  validates :participant_type, inclusion: { in: PARTICIPANT_TYPES }
  validates :gender, inclusion: { in: GENDERS }, allow_nil: true
  validates :accepted_terms_and_conditions, inclusion: { in: [true], message: "must be accepted" }
  validates :accepted_privacy_policy, inclusion: { in: [true], message: "must be accepted" }
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

  def rank_grade
    EgdGradeMapping.grade_for(rank)
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
