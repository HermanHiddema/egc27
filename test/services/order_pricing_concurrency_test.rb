require "test_helper"

class OrderPricingConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "the checkout payment attempt waits for repricing and snapshots the resulting product amount" do
    participant = participants(:three).dup
    participant.uuid = SecureRandom.uuid
    participant.email = "pricing-race-#{SecureRandom.hex(6)}@example.org"
    participant.egd_pin = nil
    participant.save!

    order_id = participant.order.id
    participant_id = participant.id
    locked = Queue.new
    release = Queue.new
    payment_attempted = Queue.new
    repricing_called = Queue.new
    payment_completed = Queue.new

    repricing_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        Order.find(order_id).with_lock do
          OrderRepricingService.call(order: Order.find(order_id), date: Date.new(2027, 2, 1))
          locked << true
          release.pop
        end
      end
    end

    locked.pop
    payment_thread = Thread.new do
      ActiveRecord::Base.connection_pool.with_connection do
        checkout_participant = Participant.find(participant_id)
        backend_pid = ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
        payment_attempted << backend_pid

        controller = PaymentsController.new
        controller.instance_variable_set(:@participant, checkout_participant)
        original_call = OrderRepricingService.method(:call)
        OrderRepricingService.define_singleton_method(:call) { |**_arguments| repricing_called << true }
        begin
          payment = controller.send(:start_new_payment_attempt)
          payment_completed << payment.amount_cents
        ensure
          OrderRepricingService.define_singleton_method(:call, original_call)
        end
      end
    end

    backend_pid = payment_attempted.pop
    wait_for_lock_wait(backend_pid)
    assert repricing_called.empty?, "checkout reached repricing without acquiring the Order lock"
    assert payment_completed.empty?, "checkout completed while repricing held the Order lock"
    release << true

    repricing_thread.value
    payment_thread.value

    assert_equal Product.where(order_id: order_id).pick(:price_cents), payment_completed.pop
  ensure
    release << true if repricing_thread&.alive?
    repricing_thread&.join
    payment_thread&.join
    participant&.destroy! if participant&.persisted?
  end

  private

  def wait_for_lock_wait(backend_pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    loop do
      wait_event_type = ActiveRecord::Base.connection.select_value(
        "SELECT wait_event_type FROM pg_stat_activity WHERE pid = #{Integer(backend_pid)}"
      )
      return if wait_event_type == "Lock"
      break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

      sleep 0.01
    end

    flunk "checkout thread did not wait on the Order row lock"
  end
end
