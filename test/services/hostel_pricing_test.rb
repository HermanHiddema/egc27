require "test_helper"

class HostelPricingTest < ActiveSupport::TestCase
  test "prices until 31 January 2027" do
    pricing = HostelPricing.new(payment_date: Date.new(2027, 1, 31))

    assert_equal :early, pricing.tier_name
    assert_equal Date.new(2027, 1, 31), pricing.current_tier_valid_until
    assert_equal 6_900, pricing.room_price_cents("single_rooms")
    assert_equal 7_900, pricing.room_price_cents("double_rooms")
    assert_equal 16_500, pricing.room_price_cents("six_person_rooms")
    assert_equal 2_900, pricing.room_price_cents("mixed_dorm_beds")
    assert_equal 2_900, pricing.room_price_cents("female_dorm_beds")
  end

  test "prices until 31 May 2027" do
    pricing = HostelPricing.new(payment_date: Date.new(2027, 2, 1))

    assert_equal :regular, pricing.tier_name
    assert_equal Date.new(2027, 5, 31), pricing.current_tier_valid_until
    assert_equal({ "single_rooms" => 7_200, "double_rooms" => 8_200, "six_person_rooms" => 18_000,
                   "mixed_dorm_beds" => 3_200, "female_dorm_beds" => 3_200 }, pricing.room_prices_cents)
  end

  test "prices from 1 June 2027" do
    pricing = HostelPricing.new(payment_date: Date.new(2027, 6, 1))

    assert_equal :late, pricing.tier_name
    assert_nil pricing.current_tier_valid_until
    assert_equal({ "single_rooms" => 7_500, "double_rooms" => 8_500, "six_person_rooms" => 19_500,
                   "mixed_dorm_beds" => 3_500, "female_dorm_beds" => 3_500 }, pricing.room_prices_cents)
  end

  test "total combines rooms and breakfasts for every night" do
    pricing = HostelPricing.new(payment_date: Date.new(2026, 11, 1))

    total = pricing.total_cents(nights: 3, rooms: { "double_rooms" => 1, "mixed_dorm_beds" => 2 }, breakfasts: 4)

    assert_equal 3 * (7_900 + 2 * 2_900 + 4 * 985), total
  end
end
