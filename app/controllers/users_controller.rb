class UsersController < ApplicationController
  before_action :require_admin!
  before_action :set_user, only: [:edit, :update]

  def index
    @users = User.order(:email, :id)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to users_path, notice: "User was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
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
