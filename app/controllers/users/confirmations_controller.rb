module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include TurnstileVerifiable

    before_action :build_turnstile_resource, only: [:create]
    before_action :verify_turnstile, only: [:create]

    def show
      # Confirm the user via the token
      self.resource = resource_class.confirm_by_token(params[:confirmation_token])
      yield resource if block_given?

      if resource.errors.empty?
        # Sign in the user immediately
        sign_in(resource)
        set_flash_message!(:notice, :confirmed)
        # Redirect to password setup - use Devise's standard path
        redirect_to edit_user_registration_path
      else
        self.confirmation_token = params[:confirmation_token]
        render :new
      end
    end

    private

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
