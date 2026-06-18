require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  test "requires all public registration fields" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:first_name], "can't be blank"
    assert_includes participant.errors[:last_name], "can't be blank"
    assert_includes participant.errors[:email], "can't be blank"
    assert_includes participant.errors[:age_group], "can't be blank"
    assert_includes participant.errors[:country], "can't be blank"
  end

  test "converts grade string to EGD grade_n integer" do
    participant = Participant.new(
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
    assert_equal(1789, participant.rating)
    assert_equal("3 kyu", participant.rank_grade)
  end

  test "supports professional grades" do
    participant = Participant.new(
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
  end

  test "validates age group must be one of the allowed values" do
    participant = Participant.new(
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
    assert_includes participant.errors[:age_group], "is not included in the list"
  end

  test "accepts all valid age group values" do
    Participant::AGE_GROUPS.each do |group|
      participant = Participant.new(
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

  test "normalizes email" do
    participant = Participant.new(
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

  test "club is optional" do
    participant = Participant.new(
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
    assert_includes participant.errors[:attendance_option], "is not included in the list"
  end

  test "requires explicit image consent choice" do
    participant = Participant.new(
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
    assert_includes participant.errors[:image_use_consent], "is not included in the list"
  end
end
