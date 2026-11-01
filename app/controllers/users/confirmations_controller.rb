module Users
  class ConfirmationsController < Devise::ConfirmationsController
    include TurnstileVerifiable

    before_action :set_registration_participant, only: [:resend_registration]
    before_action :build_turnstile_resource, only: [:create]
    before_action :verify_turnstile, only: [:create, :resend_registration]

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
        render :new, status: :unprocessable_entity
      end
    end

    def resend_registration
      @participant.user.resend_confirmation_instructions unless @participant.user.confirmed?
      redirect_to participant_path(@participant), notice: "If your registration still needs confirming, we've sent a new confirmation email."
    end

    private

    def set_registration_participant
      @participant = Participant.find_by!(uuid: params[:participant_id])
    end

    def turnstile_failure_template
      return :new unless action_name == "resend_registration"

      @personal_details_visible = user_signed_in? && @participant.user_id == current_user.id
      @has_multiple_participants = @personal_details_visible && current_user.participants.count > 1
      "participants/show"
    end

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
