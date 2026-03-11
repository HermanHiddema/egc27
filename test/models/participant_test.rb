require "test_helper"

class ParticipantTest < ActiveSupport::TestCase
  test "requires all public registration fields" do
    participant = Participant.new

    assert_not participant.valid?
    assert_includes participant.errors[:first_name], "can't be blank"
    assert_includes participant.errors[:last_name], "can't be blank"
    assert_includes participant.errors[:email], "can't be blank"
    assert_includes participant.errors[:date_of_birth], "can't be blank"
    assert_includes participant.errors[:country], "can't be blank"
  end

  test "converts grade string to EGD grade_n integer" do
    participant = Participant.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.org",
      date_of_birth: Date.new(1990, 1, 1),
      country: "NL",
      club: "Utrecht",
      rank: "3k",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: Date.new(1990, 1, 1),
      country: "RU",
      club: "Kazan",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      rank: "4p"
    )

    assert participant.valid?
    assert_equal(42, participant.rank)
    assert_equal("4 dan pro", participant.rank_grade)
  end

  test "parses european date format" do
    participant = Participant.new(
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      date_of_birth: "31-12-1999",
      country: "NL",
      club: "Eindhoven",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      rank: "1 dan"
    )

    assert participant.valid?
    assert_equal(Date.new(1999, 12, 31), participant.date_of_birth)
  end

  test "normalizes country to uppercase iso code" do
    participant = Participant.new(
      first_name: "Ana",
      last_name: "Silva",
      email: "ana@example.org",
      date_of_birth: "01-01-2000",
      country: "pt",
      club: "Porto",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: "01-01-2001",
      country: "KR",
      club: "Seoul",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: "05-06-1998",
      country: "SE",
      club: "Stockholm",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: "10-10-1997",
      country: "IT",
      club: "",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: "10-10-1997",
      country: "IT",
      rank: "8 kyu",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
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
      date_of_birth: "10-10-1997",
      country: "IT",
      rank: "8 kyu",
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      phone: "+12"
    )

    assert_not participant.valid?
    assert_includes participant.errors[:phone], "must be a valid international phone number"
  end

  test "requires acceptance of terms and privacy policy" do
    participant = Participant.new(
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      date_of_birth: "10-10-1997",
      country: "IT",
      rank: "8 kyu",
      accepted_terms_and_conditions: false,
      accepted_privacy_policy: false
    )

    assert_not participant.valid?
    assert_includes participant.errors[:accepted_terms_and_conditions], "must be accepted"
    assert_includes participant.errors[:accepted_privacy_policy], "must be accepted"
  end

  test "attendance periods default to selected" do
    participant = Participant.new

    assert_equal true, participant.first_week
    assert_equal true, participant.weekend
    assert_equal true, participant.second_week
  end
end
