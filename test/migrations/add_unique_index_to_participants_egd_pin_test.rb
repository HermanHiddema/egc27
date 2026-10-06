require "test_helper"
require Rails.root.join("db/migrate/20260708000000_add_unique_index_to_participants_egd_pin").to_s

class AddUniqueIndexToParticipantsEgdPinTest < ActiveSupport::TestCase
  parallelize(workers: 1)
  self.use_transactional_tests = false

  def setup
    super
    @created_participant_ids = []
    replace_egd_pin_index(unique: false)
  end

  def teardown
    Participant.where(id: @created_participant_ids).delete_all
    replace_egd_pin_index(unique: true)
    super
  end

  test "keeps the earliest registration for each duplicate EGD pin before adding the unique index" do
    pin = "87654321"
    earliest, middle, latest = create_duplicate_pin_participants(pin)

    ActiveRecord::Base.transaction do
      AddUniqueIndexToParticipantsEgdPin.new.migrate(:up)
    end

    assert_equal pin, earliest.reload.egd_pin
    assert_nil middle.reload.egd_pin
    assert_nil latest.reload.egd_pin
    assert ActiveRecord::Base.connection.index_exists?(:participants, :egd_pin, unique: true)
  end

  test "normalizes blank EGD pins before adding the unique index" do
    blank_pin_ids = create_blank_pin_participants

    ActiveRecord::Base.transaction do
      AddUniqueIndexToParticipantsEgdPin.new.migrate(:up)
    end

    assert_equal [nil, nil], Participant.where(id: blank_pin_ids).order(:created_at, :id).pluck(:egd_pin)
    assert ActiveRecord::Base.connection.index_exists?(:participants, :egd_pin, unique: true)
  end

  private

  def create_duplicate_pin_participants(pin)
    rows = [
      build_participant_row(email: "egd-duplicate-earliest@example.org", user: users(:one), egd_pin: pin, created_at: Time.zone.parse("2026-07-01 09:00:00")),
      build_participant_row(email: "egd-duplicate-middle@example.org", user: users(:two), egd_pin: pin, created_at: Time.zone.parse("2026-07-01 10:00:00")),
      build_participant_row(email: "egd-duplicate-latest@example.org", user: users(:dave), egd_pin: pin, created_at: Time.zone.parse("2026-07-01 11:00:00"))
    ]

    result = Participant.insert_all!(rows, returning: %w[id])
    @created_participant_ids.concat(result.rows.flatten)

    Participant.where(id: @created_participant_ids.last(3)).order(:created_at, :id).to_a
  end

  def create_blank_pin_participants
    created_at = Time.zone.parse("2026-07-01 12:00:00")
    rows = [
      build_participant_row(email: "egd-blank-pin-one@example.org", user: users(:one), egd_pin: "", created_at: created_at),
      build_participant_row(email: "egd-blank-pin-two@example.org", user: users(:two), egd_pin: "", created_at: created_at + 1.minute)
    ]

    result = Participant.insert_all!(rows, returning: %w[id])
    ids = result.rows.flatten
    @created_participant_ids.concat(ids)
    ids
  end

  def build_participant_row(email:, user:, egd_pin:, created_at:)
    {
      first_name: "Duplicate",
      last_name: "Pin",
      email: email,
      user_id: user.id,
      age_group: "18-49",
      gender: "female",
      country: "NL",
      club: "Amsterdam Go Club",
      rank: 27,
      rating: 1789,
      egd_pin: egd_pin,
      accepted_terms_and_conditions: true,
      accepted_privacy_policy: true,
      image_use_consent: true,
      participant_type: "player",
      uuid: SecureRandom.uuid,
      created_at: created_at,
      updated_at: created_at
    }
  end

  def replace_egd_pin_index(unique:)
    connection = ActiveRecord::Base.connection
    connection.remove_index(:participants, :egd_pin) if connection.index_exists?(:participants, :egd_pin)
    connection.add_index(:participants, :egd_pin, unique: unique)
  end
end
