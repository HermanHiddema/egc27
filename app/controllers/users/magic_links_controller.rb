module Users
  class MagicLinksController < ApplicationController
    skip_before_action :authenticate_user!

    def new
    end

    def create
      email = params.dig(:user, :email).to_s.strip.downcase
      user = User.find_by(email: email)
      user&.send_magic_link

      redirect_to new_user_session_path,
        notice: "If an account exists for that email address, you will receive a magic link shortly."
    end
  end
end
