require "test_helper"

class EgdSyncJobTest < ActiveSupport::TestCase
  class FakeLookup
    attr_reader :queries

    def initialize(results_by_pin)
      @results_by_pin = results_by_pin
      @queries = []
    end

    def find_by_pin(pin:)
      @queries << pin
      @results_by_pin[pin]
    end
  end

  test "updates rank and rating for participants with a valid egd pin" do
    participant = participants(:one)
    lookup = FakeLookup.new(
      participant.egd_pin => { egd_pin: participant.egd_pin, playing_strength: 32, rating: 2255 }
    )

    with_stubbed_lookup(lookup) do
      assert_equal 1, EgdSyncJob.perform_now
    end

    participant.reload
    assert_equal 32, participant.rank
    assert_equal 2255, participant.rating
    assert_includes lookup.queries, participant.egd_pin
  end

  test "skips participants without an egd pin" do
    without_pin = participants(:two)
    assert_nil without_pin.egd_pin

    lookup = FakeLookup.new({})

    with_stubbed_lookup(lookup) do
      EgdSyncJob.perform_now
    end

    assert_not_includes lookup.queries, nil
    assert_equal Participant.where.not(egd_pin: [nil, ""]).count, lookup.queries.length
  end

  test "leaves participants untouched when the lookup returns nothing" do
    participant = participants(:one)
    rank = participant.rank
    rating = participant.rating
    lookup = FakeLookup.new({})

    with_stubbed_lookup(lookup) do
      assert_equal 0, EgdSyncJob.perform_now
    end

    participant.reload
    assert_equal rank, participant.rank
    assert_equal rating, participant.rating
  end

  test "ignores results for a different pin" do
    participant = participants(:one)
    rank = participant.rank
    lookup = FakeLookup.new(
      participant.egd_pin => { egd_pin: "99999999", playing_strength: 35, rating: 2500 }
    )

    with_stubbed_lookup(lookup) do
      assert_equal 0, EgdSyncJob.perform_now
    end

    assert_equal rank, participant.reload.rank
  end

  private

  # Replaces EgdLookupService.new with a fake for the duration of the block, in
  # the same style as the other service stubs in the test suite.
  def with_stubbed_lookup(lookup)
    original_new = EgdLookupService.method(:new)
    EgdLookupService.define_singleton_method(:new) { |*| lookup }
    yield
  ensure
    EgdLookupService.define_singleton_method(:new, &original_new)
  end
end
