class ParticipantsController < ApplicationController
  include TurnstileVerifiable

  skip_before_action :authenticate_user!, only: [:index, :new, :create, :show, :egd_search, :egd_registered, :email_registered, :alter_registration, :confirm, :resend_confirmation]
  before_action :build_participant, only: [:create]
  before_action :set_participant, only: [:show, :resend_confirmation]
  before_action :verify_turnstile, only: [:create, :email_registered, :resend_confirmation]
  before_action :refuse_registration_for_existing_account, only: [:create]

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

  # Resends the participant confirmation email for this registration, identified
  # solely by the participant UUID so the email address is never exposed in the
  # page. Always responds the same way regardless of whether the registration is
  # still unconfirmed, to avoid leaking registration state.
  def resend_confirmation
    send_participant_confirmation_email(@participant) unless @participant.confirmed?

    redirect_to participant_path(@participant),
      notice: "If your registration still needs confirming, we've sent a new confirmation email."
  end

  def create
    ActiveRecord::Base.transaction do
      @participant.user = find_or_create_user_for(@participant)
      @participant.save!
    end

    if register_for_current_user?(@participant)
      # The signed-in user is registering another participant under their own
      # (already verified) account. The email is pre-filled and locked to their
      # own address, so there is nothing to confirm by email: confirm the
      # registration immediately and continue straight to the next step.
      @participant.confirm!
      redirect_to registration_next_step_path(@participant), notice: "Registration confirmed."
    else
      send_participant_confirmation_email(@participant)
      redirect_to participant_path(@participant), notice: "Registration received. You will receive a confirmation email shortly."
    end
  rescue ActiveRecord::RecordInvalid
    render :new, status: :unprocessable_entity
  end

  def confirm
    @participant = Participant.find_by!(uuid: params[:id])

    stored = @participant.confirmation_token.to_s
    token = params[:token].to_s
    if stored.present? && stored.bytesize == token.bytesize && ActiveSupport::SecurityUtils.secure_compare(stored, token)
      @participant.confirm!
      confirm_and_sign_in_user(@participant.user)
      NewsletterSubscription.subscribe_user(@participant.user)
      deliver_registration_confirmation(@participant) if @participant.email.present?
      notice = "Your registration has been confirmed."
      redirect_to registration_next_step_path(@participant), notice: notice
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

  # Checks whether the entered registration email already belongs to an account
  # so the public form can warn guests before they submit the full registration.
  def email_registered
    user = existing_user_for_email(params[:email])

    response.set_header("Cache-Control", "no-store")
    render json: email_registered_payload_for(user)
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

  # True when a signed-in (already confirmed) user is registering a participant
  # under their own account. The registration email is pre-filled and locked to
  # the current user's address, so the ownership is already verified and no
  # separate email confirmation is required. The user_id match is the
  # authoritative ownership check; the normalized email comparison is an extra
  # guard consistent with how accounts are looked up during registration.
  def register_for_current_user?(participant)
    user_signed_in? &&
      current_user.confirmed? &&
      participant.user_id == current_user.id &&
      normalize_email(participant.email) == normalize_email(current_user.email)
  end

  # An email address that already has an account may only be used for further
  # registrations by the owner of that account, so guests registering with such
  # an address are refused and asked to sign in first. Runs after the Turnstile
  # check so the response can't be used to probe for existing accounts.
  def refuse_registration_for_existing_account
    return if user_signed_in?

    user = existing_user_for_email(@participant.email)
    return if user.nil?

    redirect_to existing_account_action_url_for(user),
      alert: existing_account_alert_for(user)
  end

  def normalize_email(email)
    email.to_s.strip.downcase
  end

  def existing_user_for_email(email)
    normalized_email = normalize_email(email)
    return if normalized_email.blank?

    User.find_by(email: normalized_email)
  end

  def existing_account_alert_for(user)
    if user.confirmed?
      "An account with that email address already exists. Please log in first to register another participant."
    else
      "That email address is already registered, and a confirmation email was sent. Please open that email and confirm your email address to continue. If you cannot find the email, make sure to check your spam folder."
    end
  end

  def existing_account_action_url_for(user)
    user.confirmed? ? new_user_session_path : new_user_confirmation_path
  end

  def email_registered_payload_for(user)
    return { registered: false } if user.nil?

    {
      registered: true,
      message: existing_account_alert_for(user),
      action_url: existing_account_action_url_for(user),
      action_label: user.confirmed? ? "Log in first" : "Resend confirmation instructions"
    }
  end

  # Where to send a participant once their registration is confirmed: players
  # continue to payment, visitors go to their registration page.
  def registration_next_step_path(participant)
    if participant.player?
      new_participant_payment_path(participant)
    else
      participant_path(participant)
    end
  end

  # Sends the per-participant confirmation email for a registration. Every new
  # registration receives this same email, whether the owning account is brand
  # new, an existing unconfirmed account, or an existing confirmed account. The
  # confirmation link confirms this specific registration (and, on confirmation,
  # the owning user account too if it wasn't confirmed yet).
  def send_participant_confirmation_email(participant)
    return if participant.email.blank?

    participant.generate_confirmation_token!
    deliver_participant_confirmation(participant)
  end

  # Confirms the owning user account (if it wasn't already) when a participant
  # registration is confirmed, then signs the user in so they can proceed to
  # payment and optionally set a password afterwards. update_columns is used
  # to set confirmed_at directly, bypassing Devise's #confirm! to avoid
  # invoking the after_confirmation hook that would re-confirm already-handled
  # participants and send duplicate emails. confirmation_token,
  # confirmation_sent_at, and unconfirmed_email are also cleared to leave the
  # user in the same state as a normal Devise confirmation.
  def confirm_and_sign_in_user(user)
    return unless user

    unless user.confirmed?
      user.update_columns(
        confirmed_at: Time.current,
        confirmation_token: nil,
        confirmation_sent_at: nil,
        unconfirmed_email: nil,
        updated_at: Time.current
      )
    end

    sign_in(user)
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
    # Registration confirmation is handled by the per-participant confirmation
    # email, so suppress Devise's own on-create confirmation email.
    user.skip_confirmation_notification!
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
