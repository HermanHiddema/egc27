module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :require_authenticated_user, only: [:skip_password]

    # Newly confirmed users created during participant registration can skip
    # setting a password and go straight to their registrations. They can sign
    # in again later by requesting a magic link to their email.
    def skip_password
      redirect_to mine_participants_path,
        notice: "No problem — you can sign in any time by requesting a magic link to your email."
    end

    protected

    def update_resource(resource, params)
      # For users without a password (newly confirmed), don't require current password
      if resource.password_set?
        super
      else
        # Skip current_password validation for users without a password
        sanitized_params = params.dup
        sanitized_params.delete(:current_password)
        resource.update(sanitized_params)
      end
    end

    private

    def require_authenticated_user
      authenticate_user!
    end
  end
end
