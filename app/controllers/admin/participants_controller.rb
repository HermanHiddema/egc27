class Admin::ParticipantsController < ApplicationController
  before_action :require_admin!
  before_action :set_participant, only: [:edit, :update]

  def index
    @participants = Participant
      .includes(:payments)
      .order(last_name: :asc, first_name: :asc, id: :asc)
  end

  def edit
  end

  def update
    if @participant.update(participant_params)
      redirect_to admin_participants_path, notice: "Participant was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_participant
    @participant = Participant.find_by!(uuid: params[:id])
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :age_group, :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end
end
