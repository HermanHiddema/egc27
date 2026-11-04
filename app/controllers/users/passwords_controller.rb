module Users
  class PasswordsController < Devise::PasswordsController
    include TurnstileVerifiable

    before_action :build_turnstile_resource, only: [:create]
    before_action :verify_turnstile, only: [:create]
    before_action :identify_reset_account, only: [:edit, :update]

    def create
      super do |user|
        if user.errors.of_kind?(:email, :not_found)
          user.errors.delete(:email, :not_found)
          user.errors.add(:base, "Unknown email address.")
        end
      end
    end

    private

    def identify_reset_account
      token = action_name == "edit" ? params[:reset_password_token] : params.dig(:user, :reset_password_token)
      return unless token.is_a?(String) && token.present?

      user = resource_class.with_reset_password_token(token)
      @reset_account_email = user.email if user&.reset_password_period_valid?
    end

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
