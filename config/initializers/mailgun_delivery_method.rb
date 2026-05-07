require "mailgun-ruby"

class MailgunDeliveryMethod
  DEFAULT_API_HOST = "api.mailgun.net"

  def initialize(settings)
    @settings = settings || {}
  end

  def deliver!(mail)
    api_key = @settings[:api_key]
    domain = @settings[:domain]

    raise ArgumentError, "Mailgun API key is missing" if api_key.blank?
    raise ArgumentError, "Mailgun domain is missing" if domain.blank?

    response = Mailgun::Client.new(api_key, @settings[:api_host] || DEFAULT_API_HOST)
      .send_message(domain, message_params(mail))

    response_hash = response.respond_to?(:to_h) ? response.to_h : {}
    mail.message_id ||= response_hash["id"] if response_hash.is_a?(Hash)
    response
  end

  private

  def message_params(mail)
    params = {
      from: Array(mail.from).join(", "),
      to: Array(mail.to).join(", "),
      subject: mail.subject
    }

    params[:cc] = Array(mail.cc).join(", ") if mail.cc.present?
    params[:bcc] = Array(mail.bcc).join(", ") if mail.bcc.present?
    params[:h] = { "Reply-To" => Array(mail.reply_to).join(", ") } if mail.reply_to.present?

    if mail.multipart?
      params[:text] = mail.text_part&.decoded if mail.text_part
      params[:html] = mail.html_part&.decoded if mail.html_part
    elsif mail.mime_type == "text/html"
      params[:html] = mail.body.decoded
    else
      params[:text] = mail.body.decoded
    end

    params.compact
  end
end

ActionMailer::Base.add_delivery_method :mailgun, MailgunDeliveryMethod
