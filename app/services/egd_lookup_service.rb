require "net/http"
require "json"

# Backend connector for the European Go Database GraphQL API (version 2026.02).
# See doc/EGD_GRAPHQL_API_AGENT_REFERENCE.md for the schema this client targets.
#
# Every request is a POST of a named GraphQL operation with variables, and is
# authenticated with a personal access token read from EGD_API_TOKEN. Without a
# token the service degrades gracefully to empty results instead of raising, so
# a missing configuration never breaks registration.
class EgdLookupService
  API_URL = ENV.fetch("EGD_API_URL", "https://europeangodatabase.eu/api/v2026.02/graphql")

  # Legacy REST endpoints of the old EGD API. They are no longer used by this
  # service and only remain because the browser-side autocomplete controller
  # still queries EGD directly through them (see participants/_form.html.erb).
  BY_DATA_URL = ENV.fetch("EGD_LEGACY_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByData.php")
  BY_PIN_URL = ENV.fetch("EGD_LEGACY_PIN_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByPIN.php")

  # The API caps `limit` at 100; a search box only needs the first few hits.
  MAX_RESULTS = 10
  MIN_SEARCH_LENGTH = 2
  PIN_FORMAT = /\A\d{8}\z/
  USER_AGENT = "EGC27/participant-registration"
  OPEN_TIMEOUT = 5
  READ_TIMEOUT = 10

  PLAYER_FIELDS = "pin firstName lastName countryCode club grade rating"

  PLAYER_BY_PIN_QUERY = <<~GRAPHQL.freeze
    query PlayerByPin($pin: Int!) {
      player(pin: $pin) { #{PLAYER_FIELDS} }
    }
  GRAPHQL

  PLAYERS_SEARCH_QUERY = <<~GRAPHQL.freeze
    query SearchPlayers($search: String!, $pagination: PaginationInput!) {
      playersSearch(search: $search, pagination: $pagination) {
        data { #{PLAYER_FIELDS} }
      }
    }
  GRAPHQL

  # Free-text search used by the registration form. An 8 digit query is treated
  # as a PIN and resolved through the single-player query, which is exact.
  def search(query:)
    raw = query.to_s.strip
    return [] if raw.blank?
    return [find_by_pin(pin: raw)].compact if raw.match?(PIN_FORMAT)

    # The old REST API used a leading "@" to request a starts-with match; the
    # GraphQL search is typo tolerant, so the marker is only stripped.
    term = raw.delete_prefix("@").strip
    return [] if term.length < MIN_SEARCH_LENGTH

    data = execute(
      query: PLAYERS_SEARCH_QUERY,
      operation_name: "SearchPlayers",
      variables: { search: term, pagination: { page: 1, limit: MAX_RESULTS } }
    )

    normalize(data&.dig("playersSearch", "data")).first(MAX_RESULTS)
  end

  # Resolves a single player by PIN. Returns nil when the PIN is malformed, the
  # player is unknown, or the lookup failed.
  def find_by_pin(pin:)
    normalized = pin.to_s.strip
    return nil unless normalized.match?(PIN_FORMAT)

    data = execute(
      query: PLAYER_BY_PIN_QUERY,
      operation_name: "PlayerByPin",
      variables: { pin: normalized.to_i }
    )

    normalize([data&.dig("player")]).first
  end

  private

  # Returns the GraphQL "data" object, or nil when the request could not be
  # completed. GraphQL reports application errors with an HTTP success status,
  # so both the status and the "errors" member are inspected.
  def execute(query:, operation_name:, variables:)
    token = ENV["EGD_API_TOKEN"].presence
    if token.nil?
      Rails.logger.warn("EGD lookup skipped: EGD_API_TOKEN is not configured")
      return nil
    end

    uri = URI(API_URL)
    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{token}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request["User-Agent"] = USER_AGENT
    request.body = JSON.generate(query: query, operationName: operation_name, variables: variables)

    Rails.logger.info("EGD request host=#{uri.host} path=#{uri.path} operation=#{operation_name}")

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn(
        "EGD lookup non-success " \
        "status=#{response.code} " \
        "host=#{uri.host} " \
        "path=#{uri.path} " \
        "operation=#{operation_name}"
      )
      return nil
    end

    parse_body(response.body, operation_name: operation_name)
  rescue StandardError => e
    # The token lives in a header, so nothing request specific is logged here.
    Rails.logger.warn("EGD request failed class=#{e.class} operation=#{operation_name}")
    nil
  end

  def parse_body(body, operation_name:)
    return nil if body.blank?

    parsed = JSON.parse(body)
    return nil unless parsed.is_a?(Hash)

    errors = Array(parsed["errors"]).filter_map { |error| error.is_a?(Hash) ? error["message"] : error }
    if errors.any?
      Rails.logger.warn("EGD GraphQL errors operation=#{operation_name} messages=#{errors.join("; ")}")
    end

    data = parsed["data"]
    data.is_a?(Hash) ? data : nil
  rescue JSON::ParserError
    Rails.logger.warn("EGD response was not valid JSON operation=#{operation_name}")
    nil
  end

  # Maps EGD players onto the shape the registration form and the sync job use.
  def normalize(rows)
    Array(rows).filter_map do |row|
      next unless row.is_a?(Hash)

      first_name = presence_of(row["firstName"])
      last_name = presence_of(row["lastName"])
      next if first_name.nil? && last_name.nil?

      grade = presence_of(row["grade"])
      grade_n = EgdGradeMapping.grade_n_for(grade)

      {
        first_name: first_name,
        last_name: last_name,
        country: presence_of(row["countryCode"]),
        club: presence_of(row["club"]),
        playing_strength: grade_n,
        playing_strength_label: grade || EgdGradeMapping.grade_for(grade_n),
        rating: integer_or_nil(row["rating"]),
        egd_pin: presence_of(row["pin"])
      }
    end
  end

  def presence_of(value)
    value.to_s.strip.presence
  end

  def integer_or_nil(value)
    return nil if value.blank?

    Integer(value)
  rescue ArgumentError, TypeError
    nil
  end
end
