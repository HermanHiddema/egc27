require "test_helper"

# == Schema Information
#
# Table name: participant_tickets
#
#  id             :bigint           not null, primary key
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

  test "changes to attendance or age reprice an open product through the pricing service" do
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

  test "payment status does not establish or clear the product price" do
    participant = participants(:three)
    product = participant.order.products.sole
    original_price = product.price_cents
    payment = participant.order.payments.create!(amount_cents: original_price, description: "Payment", status: "pending")
    payment.update!(status: "paid")
    assert_equal original_price, product.reload.price_cents
  end
end
