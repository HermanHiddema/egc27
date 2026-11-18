module ParticipantRegistrationParameters
  extend ActiveSupport::Concern

  private

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :age_group,
      :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end
end
