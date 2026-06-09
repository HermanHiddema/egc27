module Users
  class RegistrationsController < Devise::RegistrationsController
    protected

    def update_resource(resource, params)
      return super if resource.password_set?

      resource.update(params.except(:current_password))
    end
  end
end
