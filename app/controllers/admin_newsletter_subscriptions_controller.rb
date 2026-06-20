class AdminNewsletterSubscriptionsController < ApplicationController
  before_action :require_admin!
  before_action :set_newsletter_subscription, only: [:edit, :update]

  def index
    @newsletter_subscriptions = NewsletterSubscription.order(created_at: :desc)
  end

  def edit
  end

  def update
    if @newsletter_subscription.update(newsletter_subscription_params)
      redirect_to admin_newsletter_subscriptions_path, notice: "Subscription was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_newsletter_subscription
    @newsletter_subscription = NewsletterSubscription.find(params[:id])
  end

  def newsletter_subscription_params
    params.require(:newsletter_subscription).permit(:first_name, :last_name, :email, :subscribed)
  end
end
