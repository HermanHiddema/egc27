require "test_helper"

class CongressPassPricingTest < ActiveSupport::TestCase
  # Special offer tier (until 31 August 2026)
  test "special offer price for all events" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31))
    assert_equal 190, pricing.price_eur
    assert_equal 19_000, pricing.price_cents
    assert_equal :special, pricing.tier_name
  end

  test "special offer price for first week plus weekend" do
    pricing = CongressPassPricing.new(attendance_option: "first_week_plus_weekend", payment_date: Date.new(2026, 7, 1))
    assert_equal 130, pricing.price_eur
  end

  test "special offer price for weekend only" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_only", payment_date: Date.new(2026, 1, 1))
    assert_equal 50, pricing.price_eur
  end

  test "special offer price for weekend plus second week" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_plus_second_week", payment_date: Date.new(2026, 8, 31))
    assert_equal 130, pricing.price_eur
  end

  # Early bird tier (1 September 2026 to 31 January 2027)
  test "early bird starts on 1 September 2026" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 9, 1))
    assert_equal 220, pricing.price_eur
    assert_equal :early, pricing.tier_name
  end

  test "early bird price for weekend only" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_only", payment_date: Date.new(2027, 1, 31))
    assert_equal 60, pricing.price_eur
  end

  # Regular tier (1 February 2027 to 30 May 2027)
  test "regular tier starts on 1 February 2027" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 2, 1))
    assert_equal 260, pricing.price_eur
    assert_equal :regular, pricing.tier_name
  end

  test "regular tier ends on 30 May 2027" do
    pricing = CongressPassPricing.new(attendance_option: "first_week_plus_weekend", payment_date: Date.new(2027, 5, 30))
    assert_equal 190, pricing.price_eur
    assert_equal :regular, pricing.tier_name
  end

  # Late tier (from 1 June 2027)
  test "late tier starts on 1 June 2027" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 6, 1))
    assert_equal 300, pricing.price_eur
    assert_equal :late, pricing.tier_name
  end

  test "late tier for weekend only" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_only", payment_date: Date.new(2027, 12, 31))
    assert_equal 80, pricing.price_eur
  end

  test "late tier for weekend plus second week" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_plus_second_week", payment_date: Date.new(2027, 9, 1))
    assert_equal 230, pricing.price_eur
  end

  # Tier boundaries
  test "last day of special offer is 31 August 2026" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31))
    assert_equal :special, pricing.tier_name
  end

  test "last day of early bird is 31 January 2027" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 1, 31))
    assert_equal :early, pricing.tier_name
  end

  test "last day of regular is 30 May 2027" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 5, 30))
    assert_equal :regular, pricing.tier_name
  end

  test "31 May 2027 is late tier" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 5, 31))
    assert_equal :late, pricing.tier_name
  end

  # Youth discounts
  test "0-11 age group gets 80% discount on special tier" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "0-11")
    assert_equal 38, pricing.price_eur  # 190 * 0.20 = 38
    assert_equal 3_800, pricing.price_cents
  end

  test "0-11 age group gets 80% discount on late tier" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 6, 1), age_group: "0-11")
    assert_equal 60, pricing.price_eur  # 300 * 0.20 = 60
  end

  test "0-11 age group gets 80% discount on weekend only" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_only", payment_date: Date.new(2026, 8, 31), age_group: "0-11")
    assert_equal 10, pricing.price_eur  # 50 * 0.20 = 10
  end

  test "12-17 age group gets 50% discount on special tier" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "12-17")
    assert_equal 95, pricing.price_eur  # 190 * 0.50 = 95
    assert_equal 9_500, pricing.price_cents
  end

  test "12-17 age group gets 50% discount on late tier" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2027, 6, 1), age_group: "12-17")
    assert_equal 150, pricing.price_eur  # 300 * 0.50 = 150
  end

  test "18-49 age group gets no discount" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "18-49")
    assert_equal 190, pricing.price_eur
  end

  test "50+ age group gets no discount" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "50+")
    assert_equal 190, pricing.price_eur
  end

  test "no age group gets no discount" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31))
    assert_equal 190, pricing.price_eur
  end

  test "base_price_eur returns undiscounted price" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "0-11")
    assert_equal 190, pricing.base_price_eur
  end

  test "discount_fraction is 0.80 for 0-11" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "0-11")
    assert_equal 0.80, pricing.discount_fraction
  end

  test "discount_fraction is 0.50 for 12-17" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "12-17")
    assert_equal 0.50, pricing.discount_fraction
  end

  test "discount_fraction is 0 for adult age groups" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 8, 31), age_group: "18-49")
    assert_equal 0, pricing.discount_fraction
  end

  # Description and labels
  test "description includes attendance label" do
    pricing = CongressPassPricing.new(attendance_option: "all_events", payment_date: Date.new(2026, 6, 1))
    assert_equal "EGC 2027 Congress Pass – Full (Week 1 + Weekend + Week 2)", pricing.description
  end

  test "attendance label for weekend only" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_only", payment_date: Date.new(2026, 6, 1))
    assert_equal "Weekend only", pricing.attendance_label
  end

  test "attendance label for first week plus weekend" do
    pricing = CongressPassPricing.new(attendance_option: "first_week_plus_weekend", payment_date: Date.new(2026, 6, 1))
    assert_equal "Week 1 + Weekend", pricing.attendance_label
  end

  test "attendance label for weekend plus second week" do
    pricing = CongressPassPricing.new(attendance_option: "weekend_plus_second_week", payment_date: Date.new(2026, 6, 1))
    assert_equal "Weekend + Week 2", pricing.attendance_label
  end
end
