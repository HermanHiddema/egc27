module Users
  class MagicLinksController < ApplicationController
    skip_before_action :authenticate_user!

    def new
    end

    def create
      email = params.dig(:user, :email).to_s.strip.downcase
      user = User.find_by(email: email)

      if user
        user.send_magic_link
        redirect_to new_user_session_path,
          notice: "Magic link sent! Check your email to sign in."
      else
        flash.now[:alert] = "No account found for that email address."
        render :new, status: :unprocessable_entity
      end
    end
  end
end
