require "net/http"
require "json"

class EgdLookupService
  BY_DATA_URL = ENV.fetch("EGD_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByData.php")
  BY_PIN_URL = ENV.fetch("EGD_PIN_API_URL", "https://europeangodatabase.eu/EGD/GetPlayerDataByPIN.php")

  MAX_RESULTS = 10

  def search(query:)
    filters = parse_query(query)
    return [] if filters[:lastname].blank?
    return [] if filters[:lastname].delete_prefix("@").length < 2

    rows = fetch_by_data(filters: filters)
    normalize(rows).first(MAX_RESULTS)
  rescue StandardError => e
    Rails.logger.warn("EGD lookup failed: #{e.class}: #{e.message}")
    []
  end

  private

  def parse_query(query)
    raw = query.to_s.strip
    return { lastname: nil, name: nil } if raw.blank?

    parts = raw.split(/\s+/).reject(&:blank?)
    return { lastname: with_starts_with_prefix(raw), name: nil } if parts.length == 1

    {
      lastname: with_starts_with_prefix(parts.last),
      name: parts[0...-1].join(" ")
    }
  end

  def with_starts_with_prefix(value)
    normalized = value.to_s.strip
    return normalized if normalized.blank? || normalized.start_with?("@")

    "@#{normalized}"
  end

  def fetch_by_data(filters:)
    params = { "lastname" => filters[:lastname] }
    params["name"] = filters[:name] if filters[:name].present?
    body = fetch_json(url: BY_DATA_URL, params: params)
    extract_rows_from_json(body)
  end

  def fetch_by_pin(pin:)
    body = fetch_json(url: BY_PIN_URL, params: { "pin" => pin })
    rows = extract_rows_from_json(body)
    rows.first
  end

  def fetch_json(url:, params:)
    uri = URI(url)
    existing_params = URI.decode_www_form(uri.query.to_s)
    uri.query = URI.encode_www_form(existing_params + params.to_a)

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "EGC27/participant-registration"
    request["Accept"] = "application/json, text/plain, */*"

    Rails.logger.info("EGD request url=#{uri} params=#{params.inspect}")

    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https") do |http|
      http.open_timeout = 5
      http.read_timeout = 10
      http.request(request)
    end

    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn(
        "EGD lookup non-success " \
        "status=#{response.code} " \
        "message=#{response.message.inspect} " \
        "url=#{uri} " \
        "content_type=#{response["content-type"].inspect} " \
        "server=#{response["server"].inspect} " \
        "cf_ray=#{response["cf-ray"].inspect} " \
        "headers=#{response.to_hash.inspect} " \
        "body_snippet=#{response.body.to_s[0, 500].inspect}"
      )
      return nil
    end

    response.body
  rescue StandardError => e
    Rails.logger.warn(
      "EGD HTTP exception class=#{e.class} message=#{e.message.inspect} url=#{uri} params=#{params.inspect}"
    )
    nil
  end

  def extract_rows_from_json(body)
    return [] if body.blank?

    parsed = JSON.parse(body)
    return parsed if parsed.is_a?(Array)

    if parsed.is_a?(Hash)
      return parsed["players"] if parsed["players"].is_a?(Array)

      array_key = parsed.keys.find { |key| parsed[key].is_a?(Array) }
      return parsed[array_key] if array_key.present?

      return [parsed]
    end

    []
  end

  def normalize(rows)
    seen = {}

    rows.filter_map do |row|
      first_name, last_name = extract_names(row)
      grade_n_value = extract_grade_n(row)
      normalized = {
        first_name: first_name,
        last_name: last_name,
        date_of_birth: normalize_date(value_for(row, %w[date_of_birth birth_date dob birthday])),
        country: value_for(row, %w[country country_code countrycode]).presence,
        club: value_for(row, %w[city town club club_city]).presence,
        playing_strength: grade_n_value,
        playing_strength_label: extract_grade_label(row, grade_n_value),
        rating: extract_rating(row),
        egd_pin: value_for(row, %w[pin_player egd_pin pin id]).presence
      }

      next if normalized[:first_name].blank? && normalized[:last_name].blank?

      key = [normalized[:egd_pin], normalized[:first_name], normalized[:last_name]].join("|")
      next if seen[key]

      seen[key] = true
      normalized
    end
  end

  def extract_grade_n(row)
    grade_n_value = value_for(row, %w[grade_n graden rank_n playing_strength_n strength_n])
    grade_value = value_for(row, %w[grade rank playing_strength strength])
    EgdGradeMapping.grade_n_for(grade_n_value.presence || grade_value)
  end

  def extract_grade_label(row, grade_n)
    value_for(row, %w[grade rank playing_strength strength]).presence || EgdGradeMapping.grade_for(grade_n)
  end

  def extract_rating(row)
    raw = value_for(row, %w[rating gor elo])
    return nil if raw.blank?

    Integer(raw)
  rescue ArgumentError, TypeError
    nil
  end

  def extract_names(row)
    first = value_for(row, %w[first_name firstname given_name givenname name]).presence
    last = value_for(row, %w[last_name lastname surname family_name]).presence

    if last.blank? && first&.include?(",")
      parts = first.split(",", 2).map(&:strip)
      last = parts[0]
      first = parts[1]
    end

    [first, last]
  end

  def value_for(row, keys)
    normalized = row.to_h.transform_keys { |key| normalize_header(key) }
    keys.each do |key|
      value = normalized[key]
      return value.to_s.strip if value.present?
    end

    nil
  end

  def normalize_header(value)
    value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, "_")
  end

  def normalize_date(value)
    raw = value.to_s.strip
    return nil if raw.blank?

    Date.parse(raw).iso8601
  rescue ArgumentError
    nil
  end
end
