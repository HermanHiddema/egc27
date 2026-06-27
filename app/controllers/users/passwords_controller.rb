module Users
  class PasswordsController < Devise::PasswordsController
    include TurnstileVerifiable

    before_action :build_turnstile_resource, only: [:create]
    before_action :verify_turnstile, only: [:create]

    private

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
