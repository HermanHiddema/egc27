module Users
  class ConfirmationsController < Devise::ConfirmationsController
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
  end
end
