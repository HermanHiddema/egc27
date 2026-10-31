module Users
  class PasswordsController < Devise::PasswordsController
    include TurnstileVerifiable

    before_action :build_turnstile_resource, only: [:create]
    before_action :verify_turnstile, only: [:create]

    def edit
      token = params[:reset_password_token]
      token_resource = resource_class.with_reset_password_token(token)

      self.resource = resource_class.new
      if token_resource
        unless token_resource.reset_password_period_valid?
          resource.errors.add(:reset_password_token, :expired)
        end
      else
        resource.errors.add(:reset_password_token, :invalid)
      end

      resource.reset_password_token = token
      set_minimum_password_length
    end

    private

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
