class CongressPassPricing
  PRICE_TIERS = [
    { name: :special,  until: Date.new(2026, 8, 31) },
    { name: :early,    until: Date.new(2027, 1, 31) },
    { name: :regular,  until: Date.new(2027, 5, 30) },
    { name: :late,     until: nil }
  ].freeze

  PRICES = {
    "all_events"              => { special: 190, early: 220, regular: 260, late: 300 },
    "first_week_plus_weekend" => { special: 130, early: 160, regular: 190, late: 230 },
    "weekend_only"            => { special: 50,  early: 60,  regular: 70,  late: 80  },
    "weekend_plus_second_week" => { special: 130, early: 160, regular: 190, late: 230 }
  }.freeze

  attr_reader :attendance_option, :payment_date

  def initialize(attendance_option:, payment_date: Date.current)
    @attendance_option = attendance_option
    @payment_date = payment_date
  end

  def price_eur
    tier = current_tier
    PRICES.fetch(attendance_option).fetch(tier)
  end

  def price_cents
    price_eur * 100
  end

  def tier_name
    current_tier
  end

  def description
    "EGC 2027 Congress Pass – #{attendance_label}"
  end

  def attendance_label
    case attendance_option
    when "all_events"               then "Full (Week 1 + Weekend + Week 2)"
    when "first_week_plus_weekend"  then "Week 1 + Weekend"
    when "weekend_only"             then "Weekend only"
    when "weekend_plus_second_week" then "Weekend + Week 2"
    else attendance_option
    end
  end

  private

  def current_tier
    PRICE_TIERS.find { |t| t[:until].nil? || payment_date <= t[:until] }.fetch(:name)
  end
end
