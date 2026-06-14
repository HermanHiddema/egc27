class ParticipantsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: [:index, :new, :create, :egd_search]
  before_action :build_participant, only: [:create]
  before_action :verify_turnstile, only: [:create]

  def index
    @countries = Participant.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)
    @country_filter = params[:country].to_s.upcase.presence
    @sort = permitted_sort
    @direction = permitted_direction

    participants = Participant.all
    participants = participants.where(country: @country_filter) if @country_filter.present?

    @participants = sorted_participants(participants)
  end

  def new
    @participant = Participant.new
  end

  def create
    ActiveRecord::Base.transaction do
      @participant.save!
      user = find_or_create_user_for(@participant)
      # update_column intentionally skips callbacks/validations since the record is already saved
      @participant.update_column(:user_id, user.id) if user
    end

    redirect_to new_participant_payment_path(@participant), notice: "Registration received. Please complete your payment below."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def egd_search
    results = EgdLookupService.new.search(query: params[:q].to_s)
    render json: results
  end

  private

  def permitted_sort
    %w[name country club rank rating].include?(params[:sort]) ? params[:sort] : "name"
  end

  def permitted_direction
    params[:direction] == "desc" ? :desc : :asc
  end

  def sorted_participants(participants)
    case @sort
    when "country"
      participants.order(country: @direction, last_name: :asc, first_name: :asc, id: :asc)
    when "club"
      participants.order(club: @direction, last_name: :asc, first_name: :asc, id: :asc)
    when "rank"
      participants.order(rank: @direction, last_name: :asc, first_name: :asc, id: :asc)
    when "rating"
      participants.order(rating: @direction, last_name: :asc, first_name: :asc, id: :asc)
    else
      participants.order(last_name: @direction, first_name: @direction, id: :asc)
    end
  end

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
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :date_of_birth, :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end

  def build_participant
    @participant = Participant.new(participant_params)
  end
end
