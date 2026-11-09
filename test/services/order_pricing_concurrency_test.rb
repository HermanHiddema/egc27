require "test_helper"

class OrderPricingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "payment creation waits for repricing and snapshots the resulting product amount" do
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.email = "pricing-race-#{SecureRandom.hex(6)}@example.org"
    participant.egd_pin = nil
    participant.save!

    order = participant.order
    locked = Queue.new
    release = Queue.new
    payment_amount = Queue.new
    attempting_payment = Queue.new

    repricing_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        order.reload.with_lock do
          OrderRepricingService.call(order:, date: Date.new(2027, 2, 1))
          locked << true
          release.pop
        end
      end
    end

    locked.pop
    payment_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        attempting_payment << true
        order.reload.with_lock do
          OrderRepricingService.call(order:, date: Date.new(2027, 2, 1))
          payment = Payment.build_for(participant).tap(&:save!)
          payment_amount << payment.amount_cents
        end
      end
    end
    attempting_payment.pop
    release << true

    repricing_thread.join
    payment_thread.join

    assert_equal Product.where(order_id: order.id).pick(:price_cents), payment_amount.pop
  ensure
    release << true if repricing_thread&.alive?
    repricing_thread&.join
    payment_thread&.join
    participant&.destroy! if participant&.persisted?
  end
end
