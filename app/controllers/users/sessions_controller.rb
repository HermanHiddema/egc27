module Users
  class SessionsController < Devise::SessionsController
    before_action :log_attempt, only: :create

    def create
      Rails.logger.info("=== LOGIN ATTEMPT ===")
      Rails.logger.info("Email: #{user_params[:email]}")
      Rails.logger.info("Password present: #{user_params[:password].present?}")
      
      user = User.find_by(email: user_params[:email])
      if user
        Rails.logger.info("User found: #{user.email}")
        Rails.logger.info("Password valid: #{user.valid_password?(user_params[:password])}")
      else
        Rails.logger.info("User not found")
      end
      
      super
    end

    def after_sign_in_path_for(resource)
      Rails.logger.info("=== SIGN IN SUCCESSFUL ===")
      Rails.logger.info("User: #{resource.email}")
      authenticated_root_path
    end

    def after_sign_out_path_for(resource_or_scope)
      new_user_session_path
    end

    private

    def log_attempt
      Rails.logger.info("=== NEW LOGIN ATTEMPT ===")
      Rails.logger.info("Session ID: #{request.session_options[:id]}")
    end

    def user_params
      params.require(:user).permit(:email, :password, :remember_me)
    end
  end
end
