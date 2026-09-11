require "test_helper"

class EgdLookupServiceTest < ActiveSupport::TestCase
  PLAYER = {
    "pin" => 10000001,
    "firstName" => "Herman",
    "lastName" => "Hiddema",
    "countryCode" => "NL",
    "club" => "Gron",
    "grade" => "4d",
    "rating" => 2409
  }.freeze

  test "resolves a pin through the player query" do
    result = with_graphql_response({ "data" => { "player" => PLAYER } }) do
      EgdLookupService.new.find_by_pin(pin: "10000001")
    end

    assert_equal "Herman", result[:first_name]
    assert_equal "Hiddema", result[:last_name]
    assert_equal "NL", result[:country]
    assert_equal "Gron", result[:club]
    assert_equal 33, result[:playing_strength]
    assert_equal "4d", result[:playing_strength_label]
    assert_equal 2409, result[:rating]
    assert_equal "10000001", result[:egd_pin]
  end

  test "posts a named query with variables and a bearer token" do
    request = nil

    with_graphql_response({ "data" => { "player" => PLAYER } }) do |captured|
      EgdLookupService.new.find_by_pin(pin: "10000001")
      request = captured.first
    end

    assert_equal "POST", request.method
    assert_equal "Bearer test-egd-token", request["Authorization"]
    assert_equal "application/json", request["Content-Type"]

    body = JSON.parse(request.body)
    assert_equal "PlayerByPin", body["operationName"]
    assert_includes body["query"], "player(pin: $pin)"
    assert_equal({ "pin" => 10000001 }, body["variables"])
  end

  test "searches by free text with pagination" do
    request = nil
    payload = { "data" => { "playersSearch" => { "data" => [PLAYER] } } }

    results = with_graphql_response(payload) do |captured|
      value = EgdLookupService.new.search(query: "Hiddema")
      request = captured.first
      value
    end

    body = JSON.parse(request.body)
    assert_equal "SearchPlayers", body["operationName"]
    assert_equal "Hiddema", body["variables"]["search"]
    assert_equal({ "page" => 1, "limit" => EgdLookupService::MAX_RESULTS }, body["variables"]["pagination"])
    assert_equal 1, results.length
    assert_equal "Hiddema", results.first[:last_name]
  end

  test "search resolves an eight digit query as a pin" do
    request = nil

    results = with_graphql_response({ "data" => { "player" => PLAYER } }) do |captured|
      value = EgdLookupService.new.search(query: " 10000001 ")
      request = captured.first
      value
    end

    assert_equal "PlayerByPin", JSON.parse(request.body)["operationName"]
    assert_equal ["10000001"], results.map { |row| row[:egd_pin] }
  end

  test "strips the legacy starts-with marker and skips too short queries" do
    request = nil

    with_graphql_response({ "data" => { "playersSearch" => { "data" => [] } } }) do |captured|
      EgdLookupService.new.search(query: "@Hi")
      request = captured.first
    end

    assert_equal "Hi", JSON.parse(request.body)["variables"]["search"]

    with_graphql_response({ "data" => { "playersSearch" => { "data" => [] } } }) do |captured|
      assert_equal [], EgdLookupService.new.search(query: "@a")
      assert_empty captured
    end
  end

  test "returns nothing for an unknown pin" do
    result = with_graphql_response({ "data" => { "player" => nil } }) do
      EgdLookupService.new.find_by_pin(pin: "99999999")
    end

    assert_nil result
  end

  test "returns nothing for a malformed pin without calling the api" do
    with_graphql_response({ "data" => { "player" => PLAYER } }) do |captured|
      assert_nil EgdLookupService.new.find_by_pin(pin: "123")
      assert_empty captured
    end
  end

  test "returns nothing when the api reports graphql errors" do
    payload = { "data" => nil, "errors" => [{ "message" => "Unauthenticated." }] }

    result = with_graphql_response(payload) do
      EgdLookupService.new.find_by_pin(pin: "10000001")
    end

    assert_nil result
  end

  test "returns nothing on an unsuccessful http status" do
    result = with_graphql_response({}, status: "401") do
      EgdLookupService.new.find_by_pin(pin: "10000001")
    end

    assert_nil result
  end

  test "returns nothing when the request raises" do
    with_token do
      with_stubbed_net_http_start(->(*_args) { raise Errno::ECONNREFUSED }) do
        assert_nil EgdLookupService.new.find_by_pin(pin: "10000001")
        assert_equal [], EgdLookupService.new.search(query: "Hiddema")
      end
    end
  end

  test "skips the lookup when no token is configured" do
    previous = ENV["EGD_API_TOKEN"]
    ENV.delete("EGD_API_TOKEN")

    with_stubbed_net_http_start(->(*_args) { raise Minitest::Assertion, "expected no EGD request without a token" }) do
      assert_nil EgdLookupService.new.find_by_pin(pin: "10000001")
      assert_equal [], EgdLookupService.new.search(query: "Hiddema")
    end
  ensure
    previous ? ENV["EGD_API_TOKEN"] = previous : ENV.delete("EGD_API_TOKEN")
  end

  private

  # Runs the block with a configured token and a stubbed HTTP layer that always
  # answers with the given payload. Yields the list of captured requests.
  def with_graphql_response(payload, status: "200")
    requests = []
    response = FakeResponse.new(status: status, body: JSON.generate(payload))

    with_token do
      with_stubbed_net_http_start(lambda { |*_args, **_kwargs, &block|
        block.call(FakeHttp.new(requests, response))
      }) do
        yield requests
      end
    end
  end

  def with_token
    previous = ENV["EGD_API_TOKEN"]
    ENV["EGD_API_TOKEN"] = "test-egd-token"
    yield
  ensure
    previous ? ENV["EGD_API_TOKEN"] = previous : ENV.delete("EGD_API_TOKEN")
  end

  def with_stubbed_net_http_start(replacement)
    original_start = Net::HTTP.method(:start)
    Net::HTTP.define_singleton_method(:start, &replacement)
    yield
  ensure
    Net::HTTP.define_singleton_method(:start, &original_start)
  end

  class FakeHttp
    def initialize(requests, response)
      @requests = requests
      @response = response
    end

    attr_accessor :open_timeout, :read_timeout

    def request(request)
      @requests << request
      @response
    end
  end

  class FakeResponse < Net::HTTPResponse
    attr_reader :body

    def initialize(status:, body:)
      super("1.1", status, "")
      @body = body
      @status = status
    end

    def is_a?(klass)
      return @status.start_with?("2") if klass == Net::HTTPSuccess

      super
    end
  end
end
