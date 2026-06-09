class NewsletterSubscriptionsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: [:new, :create, :unsubscribe, :destroy]
  before_action :prepare_newsletter_subscription, only: [:create]
  before_action :verify_turnstile, only: [:create]

  def new
    @newsletter_subscription = NewsletterSubscription.new
  end

  def create
    email = NewsletterSubscription.normalize_email(newsletter_subscription_params[:email])
    retried_create = false

    begin
      @newsletter_subscription = NewsletterSubscription.find_or_initialize_by(email: email)
      @newsletter_subscription.assign_attributes(newsletter_subscription_params)
      @newsletter_subscription.subscribed = true
      @newsletter_subscription.unsubscribed_at = nil

      if @newsletter_subscription.save
        redirect_to newsletter_path, notice: "Thanks for subscribing to the newsletter."
      else
        render :new, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotUnique
      raise if retried_create

      retried_create = true
      @newsletter_subscription = NewsletterSubscription.find_or_initialize_by(email: email)
      @newsletter_subscription.unsubscribe_token = nil
      retry
    end
  end

  def unsubscribe
    @newsletter_subscription = NewsletterSubscription.find_by(unsubscribe_token: params[:token].to_s)

    return if @newsletter_subscription

    redirect_to root_path, alert: "Invalid unsubscribe link."
  end

  def destroy
    subscription = NewsletterSubscription.find_by(unsubscribe_token: params[:token].to_s)

    return redirect_to root_path, alert: "Invalid unsubscribe link." unless subscription

    subscription.unsubscribe!
    redirect_to root_path, notice: "You have been unsubscribed from the newsletter."
  end

  private

  def prepare_newsletter_subscription
    return unless params[:newsletter_subscription].present?

    @newsletter_subscription = NewsletterSubscription.new(newsletter_subscription_params)
  end

  def newsletter_subscription_params
    params.require(:newsletter_subscription).permit(:first_name, :last_name, :email)
  end
end
