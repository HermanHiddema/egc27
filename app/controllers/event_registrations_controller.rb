class EventRegistrationsController < ApplicationController
  before_action :require_admin!, only: [:destroy]
  before_action :set_event
  before_action :ensure_user_has_participants, only: [:new, :create]
  before_action :set_registrable_participants, only: [:new, :create]

  def new
    @event_registration = EventRegistration.new
  end

  def create
    @event_registration = @event.event_registrations.build(participant: selected_participant)

    if @event_registration.participant.nil?
      @event_registration.errors.add(:base, participant_selection_error_message)
      render :new, status: :unprocessable_entity
    elsif @event_registration.save
      redirect_to @event, notice: "You have been successfully registered for this event."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    @event_registration = @event.event_registrations.find(params[:id])
    @event_registration.destroy
    redirect_to @event, notice: "Registration was removed."
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def ensure_user_has_participants
    return if current_user.participants.exists?

    redirect_to @event, alert: "Your account needs at least one participant before you can register for an event."
  end

  def set_registrable_participants
    @registrable_participants = registrable_participants_for_current_user
  end

  def registrable_participants_for_current_user
    current_user.participants
      .where.not(id: @event.event_registrations.select(:participant_id))
      .order(:last_name, :first_name, :id)
  end

  def selected_participant
    participant_id = event_registration_params[:participant_id]
    return @registrable_participants.first if participant_id.blank? && @registrable_participants.one?

    @registrable_participants.find_by(id: participant_id)
  end

  def participant_selection_error_message
    if @registrable_participants.empty?
      "All of your participants are already registered for this event."
    else
      "Select one of your participants to register."
    end
  end

  def event_registration_params
    params.fetch(:event_registration, {}).permit(:participant_id)
  end
end
