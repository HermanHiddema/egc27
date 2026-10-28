class NewsletterMailer < ApplicationMailer
  def newsletter(newsletter, subscription)
    @newsletter = newsletter
    @subscription = subscription
    @content_html = ApplicationController.helpers.render_html_content(absolute_email_urls(newsletter.content_html))

    mail(to: subscription.email, subject: newsletter.subject)
  end

  private

  def absolute_email_urls(html)
    url_options = Rails.application.config.action_mailer.default_url_options
    host = url_options.fetch(:host)
    protocol = url_options.fetch(:protocol, "https")
    port = url_options[:port]
    authority = port.present? ? "#{host}:#{port}" : host
    base_url = "#{protocol}://#{authority}"

    html = html.gsub(/(src|href)=(['"])https?:\/\/(?:localhost|127\.0\.0\.1)(?::\d+)?(\/[^'"]*)\2/i) do
      "#{$1}=#{$2}#{base_url}#{$3}#{$2}"
    end

    html.gsub(/(src|href)=(['"])(\/[^'"]*)\2/i) do
      "#{$1}=#{$2}#{base_url}#{$3}#{$2}"
    end
  end
end
