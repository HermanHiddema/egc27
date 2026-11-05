class EmailAddressValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if value.blank?

    domain = value.to_s.split("@", 2).last
    return if URI::MailTo::EMAIL_REGEXP.match?(value) && /\A[^.\s@]+(?:\.[^.\s@]+)+\z/.match?(domain)

    record.errors.add(attribute, :invalid)
  end
end
