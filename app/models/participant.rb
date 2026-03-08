class Participant < ApplicationRecord
  PARTICIPANT_TYPES = %w[player visitor].freeze

  validates :first_name, :last_name, :email, :date_of_birth, :country, :playing_strength, presence: true
  validates :participant_type, inclusion: { in: PARTICIPANT_TYPES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :country, format: { with: /\A[A-Z]{2}\z/, message: "must be an ISO 3166-1 alpha-2 code" }
  validates :rating, numericality: { only_integer: true }, allow_nil: true
  validates :playing_strength, numericality: {
    only_integer: true,
    greater_than_or_equal_to: EgdGradeMapping::MIN_GRADE_N,
    less_than_or_equal_to: EgdGradeMapping::MAX_GRADE_N
  }

  before_validation :normalize_text_fields
  before_validation :normalize_participant_type
  before_validation :normalize_date_of_birth
  before_validation :normalize_playing_strength
  before_validation :normalize_rating

  def playing_strength_grade
    EgdGradeMapping.grade_for(playing_strength)
  end

  private

  def normalize_text_fields
    self.first_name = first_name.to_s.strip
    self.last_name = last_name.to_s.strip
    self.email = email.to_s.strip.downcase.presence
    self.country = country.to_s.strip.upcase
    self.city = city.to_s.strip
    self.egd_pin = egd_pin.to_s.strip.presence
  end

  def normalize_participant_type
    self.participant_type = participant_type.to_s.strip.downcase.presence || "player"
  end

  def normalize_playing_strength
    self.playing_strength = EgdGradeMapping.grade_n_for(playing_strength)
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
