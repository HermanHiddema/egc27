class NewslettersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
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
    return redirect_to newsletter_signup_path, alert: "Sent newsletters cannot be edited." if @newsletter.sent?

    if @newsletter.update(newsletter_params)
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
end
