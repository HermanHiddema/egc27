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

      product = @order.products.includes(:productable).sole
      return @order unless product.productable.is_a?(ParticipantTicket)

      participant = product.productable.participant
      return @order unless Participant::ATTENDANCE_OPTIONS.key?(participant.attendance_option) &&
        Participant::AGE_GROUPS.include?(participant.age_group)

      price_cents = product.productable.price_for(date: @date)
      product.reprice!(price_cents) if product.price_cents != price_cents
      @order
    end
  end

  private

  def active_mollie_attempt?
    @order.payments.where(provider: "mollie", status: Payment::RETRYABLE_MOLLIE_STATUSES).exists?
  end
end
