class NewsletterSubscriptionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :unsubscribe]

  def new
    @newsletter_subscription = NewsletterSubscription.new
  end

  def create
    email = NewsletterSubscription.normalize_email(newsletter_subscription_params[:email])
    @newsletter_subscription = NewsletterSubscription.find_or_initialize_by(email: email)
    @newsletter_subscription.assign_attributes(newsletter_subscription_params)
    @newsletter_subscription.subscribed = true
    @newsletter_subscription.unsubscribed_at = nil

    if @newsletter_subscription.save
      redirect_to newsletter_path, notice: "Thanks for subscribing to the newsletter."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def unsubscribe
    subscription = NewsletterSubscription.find_by(unsubscribe_token: params[:token].to_s)

    if subscription
      subscription.unsubscribe!
      redirect_to root_path, notice: "You have been unsubscribed from the newsletter."
    else
      redirect_to root_path, alert: "Invalid unsubscribe link."
    end
  end

  private

  def newsletter_subscription_params
    params.require(:newsletter_subscription).permit(:first_name, :last_name, :email)
  end
end
