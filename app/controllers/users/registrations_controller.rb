module Users
  class RegistrationsController < Devise::RegistrationsController
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
  end
end
