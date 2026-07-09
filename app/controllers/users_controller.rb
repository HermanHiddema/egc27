class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: [:edit, :update]

  # Roles that are highlighted by default (staff), since regular users are too
  # numerous to be useful in the default listing.
  STAFF_ROLES = %w[admin editor].freeze

  def index
    @role_filter = params[:role].presence_in(User::ROLES + ["all"])

    @users = filtered_users.order(:email, :id)
  end

  def edit
  end

  def invite
    @user = User.new
  end

  def send_invitation
    @user = User.new(invitation_params)
    # Invited users are created without a password; Devise emails confirmation
    # instructions and they set their own password when confirming the account.
    @user.skip_password_validation = true

    if @user.save
      redirect_to users_path, notice: "Invitation sent to #{@user.email}."
    else
      render :invite, status: :unprocessable_entity
    end
  end

  def update
    attributes = user_update_params

    if @user == current_user && attributes["role"].present? && attributes["role"] != "admin"
      @user.errors.add(:role, "cannot be changed for your own account.")
      render :edit, status: :unprocessable_entity
      return
    end

    if @user.update(attributes)
      redirect_to users_path, notice: "User was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def filtered_users
    case @role_filter
    when "all"
      User.all
    when *User::ROLES
      User.where(role: @role_filter)
    else
      # Default view: show only staff (admins and editors).
      User.where(role: STAFF_ROLES)
    end
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted_attributes = [:email, :full_name, :password, :password_confirmation]
    permitted_attributes << :role if current_user&.admin?

    params.require(:user).permit(permitted_attributes)
  end

  def invitation_params
    permitted_attributes = [:email, :full_name]
    permitted_attributes << :role if current_user&.admin?

    params.require(:user).permit(permitted_attributes)
  end

  def user_update_params
    attributes = user_params.to_h

    if attributes["password"].blank?
      attributes.except!("password", "password_confirmation")
    end

    attributes
  end
end
