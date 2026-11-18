module EuropeanDateParameters
  extend ActiveSupport::Concern

  private

  def normalize_european_dates(attributes, dates: [], datetimes: [])
    @invalid_european_dates = {}
    (dates + datetimes).each do |field|
      value = attributes[field]
      next unless value.is_a?(String) && value.include?("/")

      datetime = datetimes.include?(field)
      pattern = datetime ? /\A(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2})\z/ : /\A(\d{2})\/(\d{2})\/(\d{4})\z/
      match = pattern.match(value)
      if match && match[3].to_i.positive? && Date.valid_date?(match[3].to_i, match[2].to_i, match[1].to_i) &&
          (!datetime || (match[4].to_i < 24 && match[5].to_i < 60))
        date = Date.new(match[3].to_i, match[2].to_i, match[1].to_i).iso8601
        attributes[field] = datetime ? "#{date}T#{match[4]}:#{match[5]}" : date
      else
        attributes[field] = nil
        @invalid_european_dates[field] = datetime ? "must be a valid date and time in dd/mm/yyyy hh:mm format" : "must be a valid date in dd/mm/yyyy format"
      end
    end
    attributes
  end

  def add_european_date_errors(record)
    (@invalid_european_dates || {}).each do |field, message|
      record.errors.delete(field, :blank)
      record.errors.add(field, message)
    end
  end
end
