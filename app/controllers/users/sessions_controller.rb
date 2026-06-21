module Users
  class SessionsController < Devise::SessionsController
    def after_sign_in_path_for(_resource)
      root_path
    end

    def after_sign_out_path_for(_resource_or_scope)
      new_user_session_path
    end
  end
end
