class CongressPassPricing
  PRICE_TIERS = [
    { name: :special,  until: Date.new(2026, 8, 31) },
    { name: :early,    until: Date.new(2027, 1, 31) },
    { name: :regular,  until: Date.new(2027, 5, 31) },
    { name: :late,     until: nil }
  ].freeze

  PRICES = {
    "all_events"              => { special: 190, early: 220, regular: 260, late: 300 },
    "first_week_plus_weekend" => { special: 130, early: 160, regular: 190, late: 230 },
    "weekend_only"            => { special: 50,  early: 60,  regular: 70,  late: 80  },
    "weekend_plus_second_week" => { special: 130, early: 160, regular: 190, late: 230 }
  }.freeze

  YOUTH_DISCOUNTS = {
    "0-11"  => 0.80,
    "12-17" => 0.50
  }.freeze

  AGE_GROUP_LABELS = {
    "0-11"  => "u12",
    "12-17" => "u18"
  }.freeze

  attr_reader :attendance_option, :payment_date, :age_group, :participant_number

  def initialize(attendance_option:, payment_date: Date.current, age_group: nil, participant_number: nil)
    @attendance_option = attendance_option
    @payment_date = payment_date
    @age_group = age_group
    @participant_number = participant_number
  end

  def base_price_eur
    PRICES.fetch(attendance_option).fetch(current_tier)
  end

  def discount_fraction
    YOUTH_DISCOUNTS.fetch(age_group, 0)
  end

  def price_eur
    (base_price_eur * (1 - discount_fraction)).round
  end

  def price_cents
    price_eur * 100
  end

  def tier_name
    current_tier
  end

  def current_tier_valid_until
    current_tier_config.fetch(:until)
  end

  def description
    parts = ["EGC 2027", attendance_label, age_group_label].compact
    description = parts.join(" ")
    description += " - #{participant_number}" if participant_number
    description
  end

  def age_group_label
    AGE_GROUP_LABELS[age_group]
  end

  def attendance_label
    case attendance_option
    when "all_events"               then "All events"
    when "first_week_plus_weekend"  then "Week 1 + Weekend"
    when "weekend_only"             then "Weekend Only"
    when "weekend_plus_second_week" then "Weekend + Week 2"
    else attendance_option
    end
  end

  private

  def current_tier_config
    PRICE_TIERS.find { |t| t[:until].nil? || payment_date <= t[:until] }
  end

  def current_tier
    current_tier_config.fetch(:name)
  end
end
