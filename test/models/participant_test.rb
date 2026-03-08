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
    assert_includes participant.errors[:playing_strength], "can't be blank"
  end

  test "converts grade string to EGD grade_n integer" do
    participant = Participant.new(
      first_name: "Jane",
      last_name: "Doe",
      email: "jane@example.org",
      date_of_birth: Date.new(1990, 1, 1),
      country: "NL",
      city: "Utrecht",
      playing_strength: "3k",
      rating: "1789"
    )

    assert participant.valid?
    assert_equal(27, participant.playing_strength)
    assert_equal(1789, participant.rating)
    assert_equal("3 kyu", participant.playing_strength_grade)
  end

  test "supports professional grades" do
    participant = Participant.new(
      first_name: "Ilja",
      last_name: "Shikshin",
      email: "ilja@example.org",
      date_of_birth: Date.new(1990, 1, 1),
      country: "RU",
      city: "Kazan",
      playing_strength: "4p"
    )

    assert participant.valid?
    assert_equal(42, participant.playing_strength)
    assert_equal("4 dan pro", participant.playing_strength_grade)
  end

  test "parses european date format" do
    participant = Participant.new(
      first_name: "Eva",
      last_name: "Jansen",
      email: "eva@example.org",
      date_of_birth: "31-12-1999",
      country: "NL",
      city: "Eindhoven",
      playing_strength: "1 dan"
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
      city: "Porto",
      playing_strength: "10 kyu"
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
      city: "Seoul",
      playing_strength: "2 dan"
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
      city: "Stockholm",
      playing_strength: "5 kyu"
    )

    assert participant.valid?
    assert_equal("nora.berg@example.com", participant.email)
    assert_equal("visitor", participant.participant_type)
  end

  test "city is optional" do
    participant = Participant.new(
      first_name: "Mia",
      last_name: "Rossi",
      email: "mia@example.org",
      participant_type: "player",
      date_of_birth: "10-10-1997",
      country: "IT",
      city: "",
      playing_strength: "8 kyu"
    )

    assert participant.valid?
    assert_equal("", participant.city)
  end
end
