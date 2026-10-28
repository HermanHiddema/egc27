class HostelPricing
  FIRST_ARRIVAL_DATE = Date.new(2027, 7, 24)
  LAST_DEPARTURE_DATE = Date.new(2027, 8, 7)

  PRICE_TIERS = [
    { name: :early,   until: Date.new(2027, 1, 31) },
    { name: :regular, until: Date.new(2027, 5, 31) },
    { name: :late,    until: nil }
  ].freeze

  # Prices are in euros per room (or bed) per night. The keys are the columns
  # of HostelBooking that hold the number of rooms or beds booked.
  ROOM_TYPES = {
    "single_rooms"     => { label: "1-person room", short_label: "1-person room", beds: 1, prices: { early: 69, regular: 72, late: 75 } },
    "double_rooms"     => { label: "2-person room", short_label: "2-person room", beds: 2, prices: { early: 79, regular: 82, late: 85 } },
    "six_person_rooms" => { label: "6-person room", short_label: "6-person room", beds: 6, prices: { early: 165, regular: 180, late: 195 } },
    "mixed_dorm_beds"  => { label: "1 bed in a 6-person dorm (mixed)", short_label: "mixed dorm bed", beds: 1, prices: { early: 29, regular: 32, late: 35 } },
    "female_dorm_beds" => { label: "1 bed in a 6-person dorm (female only)", short_label: "female dorm bed", beds: 1, prices: { early: 29, regular: 32, late: 35 } }
  }.freeze

  # The breakfast buffet is charged per person per night.
  BREAKFAST_CENTS = 985

  attr_reader :payment_date

  def initialize(payment_date: Date.current)
    @payment_date = payment_date
  end

  def room_price_cents(room_type)
    ROOM_TYPES.fetch(room_type).fetch(:prices).fetch(tier_name) * 100
  end

  def room_prices_cents
    ROOM_TYPES.keys.index_with { |room_type| room_price_cents(room_type) }
  end

  BREAKFAST_LABEL = "Breakfast buffet".freeze

  LineItem = Data.define(:label, :quantity, :nights, :unit_price_cents) do
    def subtotal_cents
      quantity * nights * unit_price_cents
    end
  end

  # The price calculation for the given number of nights, rooms per room type
  # ({ "single_rooms" => 1, ... }) and breakfasts per night, as one line per
  # booked item: quantity × nights × price per night.
  def line_items(nights:, rooms:, breakfasts: 0)
    items = ROOM_TYPES.filter_map do |room_type, room|
      quantity = rooms.fetch(room_type, 0).to_i
      next unless quantity.positive?

      LineItem.new(label: room[:short_label], quantity: quantity, nights: nights.to_i, unit_price_cents: room_price_cents(room_type))
    end
    if breakfasts.to_i.positive?
      items << LineItem.new(label: BREAKFAST_LABEL, quantity: breakfasts.to_i, nights: nights.to_i, unit_price_cents: BREAKFAST_CENTS)
    end
    items
  end

  # The total price in cents: the sum of the line items.
  def total_cents(nights:, rooms:, breakfasts: 0)
    line_items(nights: nights, rooms: rooms, breakfasts: breakfasts).sum(&:subtotal_cents)
  end

  def tier_name
    current_tier_config.fetch(:name)
  end

  def current_tier_valid_until
    current_tier_config.fetch(:until)
  end

  private

  def current_tier_config
    PRICE_TIERS.find { |t| t[:until].nil? || payment_date <= t[:until] }
  end
end
