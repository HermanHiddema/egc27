class OrderRepricingService
  def self.call(order:, date: Date.current)
    new(order:, date:).call
  end

  # Calculate the amount to display without changing stored prices. Checkout
  # still reprices under the Order lock before accepting the displayed amount.
  def self.preview_total_cents(order:, date: Date.current)
    new(order:, date:).preview_total_cents
  end

  def initialize(order:, date:)
    @order = order
    @date = date
  end

  def call
    @order.with_lock do
      return @order if @order.closed?
      return @order if active_mollie_attempt?

      @order.products.includes(:productable).each do |product|
        case product.productable
        when ParticipantTicket
          participant = product.productable.participant
          next unless Participant::ATTENDANCE_OPTIONS.key?(participant.attendance_option) &&
            Participant::AGE_GROUPS.include?(participant.age_group)

          price_cents = product.productable.price_for(date: @date)
          product.reprice!(price_cents) if product.price_cents != price_cents
        when HostelBooking
          product.productable.reprice!(date: @date)
        end
      end
      @order
    end
  end

  def preview_total_cents
    @order.products.sum do |product|
      case product.productable
      when ParticipantTicket
        participant = product.productable.participant
        if Participant::ATTENDANCE_OPTIONS.key?(participant.attendance_option) && Participant::AGE_GROUPS.include?(participant.age_group)
          product.productable.price_for(date: @date)
        else
          product.price_cents
        end
      when HostelBooking
        booking = product.productable
        HostelPricing.new(payment_date: @date).total_cents(
          nights: booking.nights,
          rooms: HostelBooking::ROOM_TYPES.index_with { |room_type| booking.public_send(room_type) },
          breakfasts: booking.breakfasts
        )
      else
        product.price_cents
      end
    end
  end

  private

  def active_mollie_attempt?
    @order.payments.where(provider: "mollie", status: Payment::RETRYABLE_MOLLIE_STATUSES).exists?
  end
end
