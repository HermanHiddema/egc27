class ParticipantsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: [:index, :new, :create, :show, :egd_search, :egd_registered, :alter_registration, :confirm, :resend_confirmation]
  before_action :build_participant, only: [:create]
  before_action :set_participant, only: [:show, :resend_confirmation]
  before_action :verify_turnstile, only: [:create, :resend_confirmation]

  def index
    participants = Participant.where.not(confirmed_at: nil)
    @countries = participants.where.not(country: [nil, ""]).distinct.order(:country).pluck(:country)
    @country_filter = params[:country].to_s.upcase.presence
    @sort = permitted_sort
    @direction = permitted_direction

    participants = participants.where(country: @country_filter) if @country_filter.present?

    @participants = sorted_participants(participants)
  end

  def new
    @participant = Participant.new
  end

  def mine
    participants = current_user.participants.order(last_name: :asc, first_name: :asc, id: :asc).load

    if participants.one?
      redirect_to participant_path(participants.first)
    else
      @participants = participants
    end
  end

  def show
  end

  # Resends the Devise confirmation email for the account that owns this
  # participant, identified solely by the participant UUID so the email address
  # is never exposed in the page. Always responds the same way regardless of
  # whether an unconfirmed account exists, to avoid leaking registration state.
  def resend_confirmation
    user = @participant.user

    if user && !user.confirmed?
      user.registration_participant = @participant
      user.send_confirmation_instructions
    end

    redirect_to participant_path(@participant),
      notice: "If your registration still needs confirming, we've sent a new confirmation email."
  end

  def create
    ActiveRecord::Base.transaction do
      @participant.user = find_or_create_user_for(@participant)
      @participant.save!
    end

    send_registration_confirmation_email(@participant)

    redirect_to participant_path(@participant), notice: "Registration received. You will receive a confirmation email shortly."
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def confirm
    @participant = Participant.find_by!(uuid: params[:id])

    stored = @participant.confirmation_token.to_s
    token = params[:token].to_s
    if stored.present? && stored.bytesize == token.bytesize && ActiveSupport::SecurityUtils.secure_compare(stored, token)
      @participant.confirm!
      NewsletterSubscription.subscribe_user(@participant.user)
      deliver_registration_confirmation(@participant) if @participant.email.present?
      notice = "Your registration has been confirmed."
      if @participant.player?
        redirect_to new_participant_payment_path(@participant), notice: notice
      else
        redirect_to participant_path(@participant), notice: notice
      end
    else
      redirect_to root_path, alert: "Invalid or expired confirmation link."
    end
  end

  def egd_search
    results = EgdLookupService.new.search(query: params[:q].to_s)
    render json: results
  end

  # Checks whether an EGD entry (by PIN) is already present in the participant
  # list so the registration form can warn against duplicate registrations.
  def egd_registered
    pin = params[:egd_pin].to_s.strip
    registered = pin.present? && Participant.exists?(egd_pin: pin)

    payload = { registered: registered }
    payload[:alter_url] = alter_registration_participants_path(egd_pin: pin) if registered

    render json: payload
  end

  # Entry point for someone who tried to register an EGD entry that already
  # exists. Routes them to re-access the existing account without exposing the
  # account email address on a public page.
  def alter_registration
    pin = params[:egd_pin].to_s.strip
    @participant = pin.present? ? Participant.where(egd_pin: pin).order(created_at: :asc, id: :asc).first : nil

    if @participant.nil?
      redirect_to new_participant_path, alert: "We couldn't find a registration for that EGD entry."
      return
    end

    user = @participant.user

    if user && !user.confirmed?
      redirect_to new_user_confirmation_path, notice: "Please confirm your email address to continue."
    else
      redirect_to new_user_session_path, notice: "Login to alter your registration"
    end
  end

  private

  # Sends the appropriate confirmation email after a participant registers.
  # - Confirmed account: a per-participant confirmation email so the existing
  #   account holder can confirm this specific registration.
  # - Existing unconfirmed account: re-sends the Devise account confirmation
  #   instructions (a newly created account already received them on save).
  def send_registration_confirmation_email(participant)
    user = participant.user
    return unless user

    if user.confirmed?
      participant.generate_confirmation_token!
      deliver_participant_confirmation(participant)
    elsif !user.previously_new_record?
      user.registration_participant = participant
      user.send_confirmation_instructions
    end
  end

  def deliver_registration_confirmation(participant)
    ParticipantMailer.registration_confirmation(participant).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to deliver registration confirmation for Participant #{participant.id}: #{e.class}: #{e.message}")
  end

  def deliver_participant_confirmation(participant)
    ParticipantMailer.participant_confirmation(participant).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to deliver participant confirmation for Participant #{participant.id}: #{e.class}: #{e.message}")
  end

  def set_participant
    @participant = Participant.find_by!(uuid: params[:id])
  end

  # Re-render the participant page (which hosts the resend form) when the
  # Turnstile check fails on resend_confirmation; other actions use :new.
  def turnstile_failure_template
    action_name == "resend_confirmation" ? :show : :new
  end

  def permitted_sort
    %w[name country club rank rating].include?(params[:sort]) ? params[:sort] : "rank"
  end

  def permitted_direction
    return params[:direction].to_sym if %w[asc desc].include?(params[:direction])

    # Default ordering (no explicit sort) is descending; column clicks default to ascending.
    %w[name country club rank rating].include?(params[:sort]) ? :asc : :desc
  end

  def sorted_participants(participants)
    table = Participant.arel_table

    clauses =
      case @sort
      when "country"
        [ordered(table[:country])]
      when "club"
        [ordered(nullif_blank(table[:club]))]
      when "rank"
        [ordered(table[:rank]), ordered(table[:rating])]
      when "rating"
        [ordered(table[:rating])]
      else
        [ordered(table[:last_name]), ordered(table[:first_name])]
      end

    participants.order(*clauses, table[:last_name].asc, table[:first_name].asc, table[:id].asc)
  end

  def ordered(column)
    ordering = @direction == :desc ? column.desc : column.asc
    ordering.nulls_last
  end

  def nullif_blank(column)
    Arel::Nodes::NamedFunction.new("NULLIF", [column, Arel::Nodes.build_quoted("")])
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
    user = User.new(
      email: email,
      full_name: "#{participant.first_name} #{participant.last_name}".strip,
      skip_password_validation: true
    )
    user.registration_participant = participant
    user.save!
    user
  end

  def participant_params
    params.require(:participant).permit(:first_name, :last_name, :email, :participant_type, :age_group, :country, :club, :rank, :rating, :egd_pin, :gender, :phone, :image_use_consent, :attendance_option)
  end

  def build_participant
    @participant = Participant.new(participant_params)
    @participant.email = current_user.email if user_signed_in?
  end
end
