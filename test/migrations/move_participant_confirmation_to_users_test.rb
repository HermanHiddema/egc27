require "test_helper"
require Rails.root.join("db/migrate/20261101120000_move_participant_confirmation_to_users").to_s

class MoveParticipantConfirmationToUsersTest < ActiveSupport::TestCase
  parallelize(workers: 1)

  setup do
    connection = ActiveRecord::Base.connection
    [:confirmation_token, :confirmed_at].each do |column|
      connection.remove_column(:participants, column) if connection.column_exists?(:participants, column)
    end
    connection.clear_cache!

    @migration = MoveParticipantConfirmationToUsers.new
    @migration.migrate(:down)
  end

  def after_teardown
    super
    ActiveRecord::Base.connection.clear_cache!
  end

  test "preserves confirmed users when their participants are unconfirmed" do
    user = users(:one)
    confirmed_at = user.confirmed_at
    set_participant_confirmation(participants(:one), nil)

    migrate_confirmation

    assert_equal confirmed_at, user.reload.confirmed_at
    assert_predicate participants(:one).reload, :confirmed?
  end

  test "confirms an unconfirmed user and all their participants using the earliest confirmation" do
    user = users(:one)
    user.update_columns(confirmed_at: nil)
    earliest = Time.zone.parse("2026-10-01 10:00:00")
    set_participant_confirmation(participants(:one), earliest)
    set_participant_confirmation(participants(:three), earliest + 1.day)
    set_participant_confirmation(participants(:visitor_one), nil)

    migrate_confirmation

    assert_equal earliest, user.reload.confirmed_at
    user.participants.each { |participant| assert_predicate participant, :confirmed? }
  end

  test "keeps unconfirmed users and participants unconfirmed" do
    migrate_confirmation

    assert_nil users(:pending).reload.confirmed_at
    assert_not participants(:unconfirmed).reload.confirmed?
  end

  test "preserves existing user confirmation even when participant confirmation differs" do
    user = users(:two)
    confirmed_at = user.confirmed_at
    set_participant_confirmation(participants(:two), confirmed_at - 1.day)
    users(:no_password).update_columns(confirmed_at: nil)

    migrate_confirmation

    assert_equal confirmed_at, user.reload.confirmed_at
    assert_predicate participants(:two).reload, :confirmed?
    assert_nil users(:no_password).reload.confirmed_at
    assert_not ActiveRecord::Base.connection.column_exists?(:participants, :confirmed_at)
    assert_not ActiveRecord::Base.connection.column_exists?(:participants, :confirmation_token)
  end

  private

  def migrate_confirmation
    @migration.migrate(:up)
    ActiveRecord::Base.connection.clear_cache!
  end

  def set_participant_confirmation(participant, confirmed_at)
    connection = ActiveRecord::Base.connection
    connection.execute <<~SQL
      UPDATE participants SET confirmed_at = #{connection.quote(confirmed_at)}
      WHERE id = #{connection.quote(participant.id)}
    SQL
  end
end
