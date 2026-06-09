module Users
  class RegistrationsController < Devise::RegistrationsController
    protected

    def update_resource(resource, params)
      return super if resource.password_set?

      sanitized_params = params.dup
      sanitized_params.delete(:current_password)

      resource.update(sanitized_params)
    end
  end
end
