class OrderRepricingService
  def self.call(order:, date: Date.current)
    new(order:, date:).call
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

  private

  def active_mollie_attempt?
    @order.payments.where(provider: "mollie", status: Payment::RETRYABLE_MOLLIE_STATUSES).exists?
  end
end
