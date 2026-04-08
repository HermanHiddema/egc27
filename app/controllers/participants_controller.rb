class ParticipantsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: [:index, :new, :create, :egd_search]
  before_action :build_participant, only: [:create]
  before_action :verify_turnstile, only: [:create]

  def index
    @participants = Participant.order(:last_name, :first_name, :id)
  end

  def new
    @participant = Participant.new
  end

  def create
    @participant.assign_attributes(participant_params)

    ActiveRecord::Base.transaction do
      @participant.save!
      user = find_or_create_user_for(@participant)
      # update_column intentionally skips callbacks/validations since the record is already saved
      @participant.update_column(:user_id, user.id) if user
    end

    redirect_to new_participant_path, notice: "Registration received. Thank you!"
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def egd_search
    results = EgdLookupService.new.search(query: params[:q].to_s)
    render json: results
  end

  private

  def find_or_create_user_for(participant)
    email = participant.email.to_s.strip.downcase
    return nil if email.blank?

    User.find_by(email: email) || begin
      User.transaction(requires_new: true) { create_user_for(email, participant) }
    rescue ActiveRecord::RecordNotUnique
      User.find_by(email: email)
    end
  end

  def create_user_for(email, participant)
    User.create!(
      email: email,
      full_name: "#{participant.first_name} #{participant.last_name}".strip,
      skip_password_validation: true
    )
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :date_of_birth, :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :accepted_terms_and_conditions, :accepted_privacy_policy, :image_use_consent, :first_week, :weekend, :second_week)
  end

  def build_participant
    @participant = Participant.new
  end
end
