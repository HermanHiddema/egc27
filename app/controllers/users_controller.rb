class UsersController < ApplicationController
  before_action :require_editor!, only: [:index, :edit, :update]
  before_action :require_admin!, only: [:new, :create]
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

  def update
    attributes = user_update_params

    if current_user.admin? && @user == current_user && attributes["role"].present? && attributes["role"] != "admin"
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

  def user_update_params
    attributes = user_params.to_h

    if attributes["password"].blank?
      attributes.except!("password", "password_confirmation")
    end

    attributes
  end
end
