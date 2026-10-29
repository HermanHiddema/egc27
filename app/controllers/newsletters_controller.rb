class NewslettersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show, :test_preview, :test_unsubscribe]
  before_action :require_creator!, only: [:new, :create]
  before_action :require_editor!, only: [:edit, :update, :preview, :confirm_send, :send_newsletter]
  before_action :set_newsletter, only: [:show, :edit, :update, :preview, :confirm_send, :send_newsletter]
  before_action :set_recipient_count, only: [:new, :create, :edit, :update, :preview]

  def show
    redirect_to newsletter_signup_path, alert: "That newsletter has not been sent." unless @newsletter.sent?
  end

  def new
    @newsletter = current_user.newsletters.build
  end

  def create
    @newsletter = current_user.newsletters.build(newsletter_params)
    return render_test_recipient_error(:new) if test_send_requested? && !prepare_test_recipients

    if @newsletter.save
      redirect_after_save
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    redirect_to newsletter_signup_path, alert: "Sent newsletters cannot be edited." if @newsletter.sent?
  end

  def update
    if test_send_requested? && !prepare_test_recipients
      @newsletter.assign_attributes(newsletter_params)
      return render_test_recipient_error(:edit)
    end

    result = @newsletter.with_lock do
      next :sent if @newsletter.sent?

      @newsletter.update(newsletter_params) ? :saved : :invalid
    end

    case result
    when :sent
      redirect_to newsletter_signup_path, alert: "Sent newsletters cannot be edited."
    when :saved
      redirect_after_save
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def preview
    redirect_to newsletter_signup_path, alert: "Sent newsletters cannot be previewed as drafts." if @newsletter.sent?
  end

  def confirm_send
    return redirect_to newsletter_path(@newsletter), alert: "This newsletter has already been sent." if @newsletter.sent?

    @recipient_count = NewsletterSubscription.where(subscribed: true).count
  end

  def send_newsletter
    return redirect_to newsletter_path(@newsletter), alert: "This newsletter has already been sent." if @newsletter.sent?
    return redirect_to confirm_send_newsletter_path(@newsletter), alert: "Please confirm the send before continuing." unless params[:confirmed_send] == "1"

    queue_newsletter(params[:recipient_count])
  end

  def test_preview
    @newsletter = NewsletterTestEmailLink.find_preview_newsletter(params[:token])
  rescue ActiveSupport::MessageVerifier::InvalidSignature, ActiveRecord::RecordNotFound
    head :not_found
  end

  def test_unsubscribe
    email = NewsletterTestEmailLink.email_for_unsubscribe_token(params[:token])
    subscription = NewsletterSubscription.find_by(email: NewsletterSubscription.normalize_email(email))
    subscription&.unsubscribe! if subscription&.subscribed?

    notice = subscription ? "You have been unsubscribed from the newsletter." : "This test recipient is not subscribed. No subscription was changed."
    redirect_to newsletter_signup_path, notice: notice
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    head :not_found
  end

  private

  def set_newsletter
    @newsletter = if action_name == "show"
      Newsletter.sent.find(params[:id])
    else
      Newsletter.find(params[:id])
    end
  end

  def set_recipient_count
    @recipient_count = NewsletterSubscription.where(subscribed: true).count
  end

  def newsletter_params
    params.require(:newsletter).permit(:title, :subject, :content_html)
  end

  def redirect_after_save
    case params[:intent]
    when "preview"
      redirect_to preview_newsletter_path(@newsletter)
    when "test_send"
      queue_test_newsletters
    when "send"
      if params[:confirmed_send] == "1"
        queue_newsletter(params[:recipient_count])
      else
        redirect_to confirm_send_newsletter_path(@newsletter), alert: "Please confirm the send before continuing."
      end
    else
      redirect_to edit_newsletter_path(@newsletter), notice: "Newsletter draft saved."
    end
  end

  def queue_newsletter(expected_recipient_count)
    set_recipient_count
    if expected_recipient_count.to_i != @recipient_count
      return redirect_to confirm_send_newsletter_path(@newsletter), alert: "The subscriber count changed. Please review the updated count before sending."
    end

    claimed_at = Time.current
    claimed = Newsletter.where(id: @newsletter.id, sent_at: nil).update_all(sent_at: claimed_at, updated_at: claimed_at)
    return redirect_to newsletter_path(@newsletter), alert: "This newsletter has already been sent." unless claimed == 1

    begin
      NewsletterDispatchJob.perform_later(@newsletter.id)
    rescue StandardError => error
      Newsletter.where(id: @newsletter.id, sent_at: claimed_at).update_all(sent_at: nil, updated_at: Time.current)
      Rails.logger.error("Failed to queue Newsletter #{@newsletter.id}: #{error.class}: #{error.message}")
      return redirect_to edit_newsletter_path(@newsletter), alert: "The newsletter could not be queued. Please try again."
    end

    redirect_to newsletter_path(@newsletter), notice: "Newsletter queued for #{@recipient_count} #{'addressee'.pluralize(@recipient_count)}."
  end

  def test_send_requested?
    params[:intent] == "test_send"
  end

  def prepare_test_recipients
    @test_recipients = params[:test_recipients].to_s
    @test_recipient_addresses = @test_recipients.split(/[,;\s]+/).reject(&:blank?).map(&:downcase).uniq

    @test_send_error = if @test_recipient_addresses.empty?
      "Enter at least one email address."
    elsif @test_recipient_addresses.any? { |address| !URI::MailTo::EMAIL_REGEXP.match?(address) }
      "Enter valid email addresses separated by commas, spaces, or new lines."
    end

    @test_send_error.nil?
  end

  def render_test_recipient_error(template)
    @test_send_modal_open = true
    render template, status: :unprocessable_entity
  end

  def queue_test_newsletters
    @test_recipient_addresses.each do |address|
      NewsletterMailer.test_newsletter(@newsletter, address).deliver_later
    end

    count = @test_recipient_addresses.length
    redirect_to edit_newsletter_path(@newsletter), notice: "Test email queued for #{count} #{'address'.pluralize(count)}. The newsletter remains a draft."
  rescue StandardError => error
    Rails.logger.error("Failed to queue test newsletter #{@newsletter.id}: #{error.class}: #{error.message}")
    redirect_to edit_newsletter_path(@newsletter), alert: "The test email could not be queued. Please try again."
  end
end
