class NewsletterMailer < ApplicationMailer
  layout false

  def goodbye(newsletter_subscription, resubscribe_token: nil)
    @newsletter_subscription = newsletter_subscription
    @resubscribe_url = resubscribe_newsletter_url(resubscribe_token || newsletter_subscription.subscription_token)

    mail(
      to: newsletter_subscription.email,
      subject: "EGC 2027 – You have been unsubscribed"
    )
  end

  def welcome(newsletter_subscription)
    @newsletter_subscription = newsletter_subscription
    @unsubscribe_url = unsubscribe_newsletter_url(token: newsletter_subscription.subscription_token)

    mail(
      to: newsletter_subscription.email,
      subject: "EGC 2027 – Welcome to the newsletter"
    )
  end

  def welcome_back(newsletter_subscription)
    @newsletter_subscription = newsletter_subscription
    @unsubscribe_url = unsubscribe_newsletter_url(token: newsletter_subscription.subscription_token)

    mail(
      to: newsletter_subscription.email,
      subject: "EGC 2027 – Welcome back to the newsletter"
    )
  end

  def newsletter(newsletter, subscription)
    @newsletter = newsletter
    @newsletter_title = newsletter.title
    @subscription = subscription
    @content_html = email_content(newsletter.content_html)

    mail(to: subscription.email, subject: newsletter.subject)
  end

  def test_newsletter(newsletter_id, newsletter_snapshot, recipient)
    @newsletter = Newsletter.find(newsletter_id)
    @newsletter_title = newsletter_snapshot.fetch("title")
    @subscription = nil
    @test_delivery = true
    @test_unsubscribe_url = test_newsletter_unsubscribe_url(
      token: NewsletterTestEmailLink.unsubscribe_token(recipient)
    )
    @test_preview_url = test_newsletter_preview_url(
      token: NewsletterTestEmailLink.preview_token(@newsletter)
    )
    @content_html = email_content(newsletter_snapshot.fetch("content_html"))

    mail(to: recipient, subject: "[TEST] #{newsletter_snapshot.fetch("subject")}", template_name: "newsletter")
  end

  private

  def email_content(html)
    content = ApplicationController.helpers.render_html_content(absolute_email_urls(html))
    fragment = Nokogiri::HTML.fragment(content)
    allowed_hosts = [Rails.application.config.action_mailer.default_url_options.fetch(:host), "localhost", "127.0.0.1"]

    fragment.css("img[src]").each do |image|
      uri = URI.parse(image["src"])
      next unless allowed_hosts.include?(uri.host)

      match = uri.path.to_s.match(%r{\A/newsletter-social/(facebook|instagram|x|discord|whatsapp)\.png\z})
      next unless match && uri.query.nil? && uri.fragment.nil?

      filename = "#{match[1]}.png"
      attachments.inline[filename] ||= File.binread(Rails.root.join("public/newsletter-social", filename))
      image["src"] = attachments[filename].url
    rescue URI::InvalidURIError
      next
    end

    fragment.to_html.html_safe
  end

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

    html = html.gsub(/(src|href)=(['"])(\/\/[^'"]*)\2/i) do
      "#{$1}=#{$2}#{protocol}:#{$3}#{$2}"
    end

    html.gsub(/(src|href)=(['"])(\/(?!\/)[^'"]*)\2/i) do
      "#{$1}=#{$2}#{base_url}#{$3}#{$2}"
    end
  end
end
