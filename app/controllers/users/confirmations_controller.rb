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
        redirect_to after_confirmation_path_for(resource)
      else
        self.confirmation_token = params[:confirmation_token]
        render :new
      end
    end

    private

    # After confirming, send users created via participant registration to
    # their registration. A single participant goes straight to that
    # participant's page; multiple participants go to the registrations list.
    def after_confirmation_path_for(resource)
      participants = resource.participants
      case participants.size
      when 0
        edit_user_registration_path
      when 1
        participant_path(participants.first)
      else
        mine_participants_path
      end
    end
  end
end
