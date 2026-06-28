module Users
  class SessionsController < Devise::SessionsController
    include TurnstileVerifiable

    # Prepend so the Turnstile check runs before Devise's own prepended
    # authentication filters. Otherwise Warden could authenticate (and persist
    # the session) before our :create before_action halts the request,
    # signing the user in despite a failed Turnstile check.
    prepend_before_action :verify_turnstile, only: [:create]
    prepend_before_action :build_turnstile_resource, only: [:create]

    def after_sign_out_path_for(_resource_or_scope)
      new_user_session_path
    end

    private

    # Ensure a resource is available when the Turnstile check fails and re-renders
    # the :new template before Devise has had a chance to assign one.
    def build_turnstile_resource
      self.resource ||= resource_class.new
    end
  end
end
