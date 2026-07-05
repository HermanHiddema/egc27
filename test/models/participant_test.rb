require "test_helper"

# == Schema Information
#
# Table name: participants
#
#  id                            :bigint           not null, primary key
#  accepted_privacy_policy       :boolean          default(FALSE), not null
#  accepted_terms_and_conditions :boolean          default(FALSE), not null
#  age_group                     :string           not null
#  club                          :string           not null
#  confirmation_token            :string
#  confirmed_at                  :datetime
#  country                       :string           not null
#  egd_pin                       :string
#  email                         :string           not null
#  first_name                    :string           not null
#  first_week                    :boolean          default(TRUE), not null
#  gender                        :string
#  image_use_consent             :boolean          default(NULL), not null
#  last_name                     :string           not null
#  participant_type              :string           default("player"), not null
#  phone                         :string
#  rank                          :integer
#  rating                        :integer
#  second_week                   :boolean          default(TRUE), not null
#  uuid                          :uuid             not null
#  weekend                       :boolean          default(TRUE), not null
#  created_at                    :datetime         not null
#  updated_at                    :datetime         not null
#  user_id                       :bigint           not null
#
# Indexes
#
#  index_participants_on_confirmation_token  (confirmation_token) UNIQUE
#  index_participants_on_confirmed_at        (confirmed_at)
#  index_participants_on_created_at          (created_at)
#  index_participants_on_egd_pin             (egd_pin)
#  index_participants_on_email               (email)
#  index_participants_on_gender              (gender)
#  index_participants_on_participant_type    (participant_type)
#  index_participants_on_phone               (phone)
#  index_participants_on_rating              (rating)
#  index_participants_on_user_id             (user_id)
#  index_participants_on_uuid                (uuid) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (user_id => users.id)
#
class ParticipantTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "requires all public registration fields" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:first_name], "can't be blank"
    assert_includes participant.errors[:last_name], "can't be blank"
    assert_includes participant.errors[:email], "can't be blank"
    assert_includes participant.errors[:age_group], "must be selected"
    assert_includes participant.errors[:country], "can't be blank"
  end

  test "age group has a single must be selected error when blank" do
    participant = Participant.new

    assert_not participant.valid?
    assert_equal ["must be selected"], participant.errors[:age_group]
  end

  test "does not surface a user error when email is missing" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:email], "can't be blank"
    assert_empty participant.errors[:user]
  end

  test "requires a user even when other fields are present" do
    participant = Participant.new(
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      image_use_consent: true,
      rank: "1 dan"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:user], "can't be blank"
  end

  test "derives rating from rank and ignores submitted rating without an EGD pin" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "3k",
      image_use_consent: true,
      rating: "1789"
    )

    assert participant.valid?
    assert_equal(27, participant.rank)
    # 3 kyu (grade_n 27) -> 2000 + (27 - 29) * 100 = 1800, submitted 1789 ignored.
    assert_equal(1800, participant.rating)
    assert_equal("3 kyu", participant.rank_grade)
  end

  test "keeps the EGD rating when an EGD pin is present" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane.egd@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "3k",
      image_use_consent: true,
      egd_pin: "12345678",
      rating: "1789"
    )

    assert participant.valid?
    # EGD takes priority over the rank-derived rating.
    assert_equal(1789, participant.rating)
  end

  test "falls back to the rank rating when an EGD pin has no rating" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Jane",
      last_name: "Doe",
      email: "jane.norating@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      club: "Utrecht",
      rank: "1 dan",
      image_use_consent: true,
      egd_pin: "12345678",
      rating: ""
    )

    assert participant.valid?
    # 1 dan (grade_n 30) -> 2000 + (30 - 29) * 100 = 2100.
    assert_equal(2100, participant.rating)
  end

  test "leaves rating blank when neither an EGD rating nor a rank is present" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Nina",
      last_name: "Visitor",
      email: "nina@example.org",
      age_group: "18-49",
      country: "NL",
      gender: "female",
      image_use_consent: true,
      rating: "1500"
    )

    assert participant.valid?
    assert_nil participant.rating
  end

  test "supports professional grades" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Ilja",
      last_name: "Shikshin",
      email: "ilja@example.org",
      age_group: "18-49",
      country: "RU",
      gender: "male",
      club: "Kazan",
      image_use_consent: true,
      rank: "4p"
    )

    assert participant.valid?
    assert_equal(42, participant.rank)
    assert_equal("4 dan pro", participant.rank_grade)
    # 1 dan pro is equivalent to 7 dan (2700); each further pro grade adds 30.
    assert_equal(2790, participant.rating)
  end

  test "validates age group must be one of the allowed values" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      age_group: "25-30",
      country: "NL",
      gender: "female",
      club: "Eindhoven",
      image_use_consent: true,
      rank: "1 dan"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:age_group], "must be selected"
  end

  test "accepts all valid age group values" do
    Participant::AGE_GROUPS.each do |group|
      participant = Participant.new(
        user: users(:one),
        first_name: "Eva",
        last_name: "Jansen",
        email: "eva@example.org",
        age_group: group,
        country: "NL",
        gender: "female",
        club: "Eindhoven",
        image_use_consent: true,
        rank: "1 dan"
      )

      assert participant.valid?, "Expected #{group} to be valid, but got: #{participant.errors.full_messages}"
    end
  end

  test "normalizes country to uppercase iso code" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Ana",
      last_name: "Silva",
      email: "ana@example.org",
      age_group: "18-49",
      country: "pt",
      gender: "female",
      club: "Porto",
      image_use_consent: true,
      rank: "10 kyu"
    )

    assert participant.valid?
    assert_equal("PT", participant.country)
  end

  test "defaults participant type to player" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "2 dan"
    )

    assert participant.valid?
    assert_equal("player", participant.participant_type)
  end

  test "validates EGD pin must be an 8 digit number" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee.pin@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "2 dan",
      egd_pin: "1234"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:egd_pin], "must be an 8 digit number"

    participant.egd_pin = "12345678"
    assert participant.valid?
  end

  test "clamps derived rating to the allowed range" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Lee",
      last_name: "Min",
      email: "lee.rating@example.org",
      age_group: "18-49",
      country: "KR",
      gender: "male",
      club: "Seoul",
      image_use_consent: true,
      rank: "30 kyu"
    )

    assert participant.valid?
    # 30 kyu (grade_n 0) -> 2000 + (0 - 29) * 100 = -900, within range.
    assert_equal(-900, participant.rating)
    assert_operator participant.rating, :>=, Participant::MIN_RATING

    # An out-of-range EGD rating is clamped rather than rejected.
    participant.egd_pin = "12345678"
    participant.rating = 9000
    assert participant.valid?
    assert_equal(Participant::MAX_RATING, participant.rating)
  end

  test "normalizes email" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Nora",
      last_name: "Berg",
      email: " Nora.Berg@Example.COM ",
      participant_type: "visitor",
      age_group: "18-49",
      country: "SE",
      gender: "female",
      club: "Stockholm",
      image_use_consent: true,
      rank: "5 kyu"
    )

    assert participant.valid?
    assert_equal("nora.berg@example.com", participant.email)
    assert_equal("visitor", participant.participant_type)
  end

  test "allows a duplicate EGD pin" do
    participant = participants(:one).dup
    participant.email = "different@example.org"
    participant.user = users(:two)

    assert participant.valid?
  end

  test "club is optional" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      club: "",
      image_use_consent: true,
      rank: "8 kyu"
    )

    assert participant.valid?
    assert_equal("", participant.club)
  end

  test "normalizes phone to international digits format" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      phone: "(+39) 06 1234 5678"
    )

    assert participant.valid?
    assert_equal("+390612345678", participant.phone)
  end

  test "rejects clearly invalid phone" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      phone: "+12"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:phone], "must be a valid international phone number"
  end

  test "implicitly accepts terms and privacy policy" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true
    )

    assert participant.valid?
    assert_equal true, participant.accepted_terms_and_conditions
    assert_equal true, participant.accepted_privacy_policy
  end

  test "attendance periods default to selected" do
    participant = Participant.new

    assert_equal true, participant.first_week
    assert_equal true, participant.weekend
    assert_equal true, participant.second_week
  end

  test "image consent defaults to nil for new participants" do
    assert_nil Participant.new.image_use_consent
  end

  test "attendance option updates attendance periods" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      attendance_option: "weekend_only"
    )

    assert participant.valid?
    assert_equal false, participant.first_week
    assert_equal true, participant.weekend
    assert_equal false, participant.second_week
  end

  test "rejects unknown attendance option" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: true,
      attendance_option: "unexpected"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:attendance_option], "must be selected"
  end

  test "requires explicit image consent choice" do
    participant = Participant.new(
      user: users(:one),
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      age_group: "18-49",
      country: "IT",
      gender: "female",
      rank: "8 kyu",
      image_use_consent: nil
    )

    assert_not participant.valid?
    assert_includes participant.errors[:image_use_consent], "must be selected"
  end

  test "generate_confirmation_token! retries on token collisions for legacy invalid records and updates timestamp" do
    participant = participants(:one)
    participant.update_column(:gender, nil)
    original_updated_at = participant.updated_at
    generated_tokens = ["test_token_abc123", "replacement_token_123"]
    singleton = SecureRandom.singleton_class
    original_urlsafe_base64 = SecureRandom.method(:urlsafe_base64)

    begin
      singleton.define_method(:urlsafe_base64) { |_length = nil| generated_tokens.shift }

      travel_to original_updated_at + 1.minute do
        participant.generate_confirmation_token!
      end
    ensure
      singleton.define_method(:urlsafe_base64, original_urlsafe_base64)
    end

    participant.reload
    assert_equal "replacement_token_123", participant.confirmation_token
    assert_operator participant.updated_at, :>, original_updated_at
  end

  test "confirm! clears token for legacy invalid records and updates timestamp" do
    participant = participants(:unconfirmed)
    participant.update_column(:gender, nil)
    original_updated_at = participant.updated_at

    travel_to original_updated_at + 1.minute do
      participant.confirm!
    end

    participant.reload
    assert participant.confirmed?
    assert_nil participant.confirmation_token
    assert_operator participant.updated_at, :>, original_updated_at
  end

  test "assigns a uuid on creation" do
    participant = Participant.create!(
      user: users(:one),
      first_name: "Uuid",
      last_name: "Tester",
      email: "uuid_tester@example.org",
      age_group: "18-49",
      gender: "female",
      country: "NL",
      club: "Amsterdam Go Club",
      image_use_consent: true
    )

    assert_match(/\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/, participant.uuid)
  end

  test "to_param returns the uuid" do
    participant = participants(:one)

    assert_equal participant.uuid, participant.to_param
  end
end
