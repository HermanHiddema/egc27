require "test_helper"

# == Schema Information
#
# Table name: participant_tickets
#
#  id             :bigint           not null, primary key
#  price_cents    :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  participant_id :bigint           not null
#
# Indexes
#
#  index_participant_tickets_on_participant_id  (participant_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (participant_id => participants.id)
#
class ParticipantTicketTest < ActiveSupport::TestCase
  test "a new ticket uses the participant's attendance, age and pricing tier" do
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.egd_pin = nil
    participant.age_group = "0-11"
    participant.attendance_option = "weekend_only"

    travel_to Time.zone.local(2026, 8, 1) do
      participant.save!
    end

    assert_equal 1000, participant.reload.participant_ticket.price_cents
    assert_equal "weekend_only", participant.attendance_option
  end

  test "changes to attendance or age update the price before payment starts" do
    participant = participants(:three)
    travel_to Time.zone.local(2026, 9, 1) do
      participant.update!(age_group: "12-17", attendance_option: "weekend_only")
    end
    assert_equal 3000, participant.reload.participant_ticket.price_cents
  end

  test "changing the participant does not change an already paid ticket price" do
    participant = participants(:two)
    ticket = participant.participant_ticket
    original_price = ticket.price_cents
    participant.update!(age_group: "0-11", attendance_option: "all_events")
    assert_equal original_price, ticket.reload.price_cents
    assert_equal 5000, payments(:paid_payment).reload.amount_cents
  end

  test "ticket prices must be positive integers" do
    ticket = participants(:three).participant_ticket
    [0, -100, 1.5].each do |invalid_price|
      ticket.price_cents = invalid_price
      assert_not ticket.valid?
      assert ticket.errors[:price_cents].any?
    end
  end
  test "a newly recorded payment locks the ticket price" do
    participant = participants(:three)
    payment = participant.order.payments.create!(amount_cents: 12345, description: "Payment", status: "pending")
    assert_equal 12345, participant.participant_ticket.reload.price_cents
    assert_equal 12345, payment.reload.amount_cents
  end
end
