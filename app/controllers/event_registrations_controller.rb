class EventRegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  before_action :require_admin!, only: [:destroy]
  before_action :set_event

  def new
    @event_registration = EventRegistration.new
  end

  def create
    participant = Participant.find_by(email: params[:event_registration][:email]&.strip&.downcase)

    if participant.nil?
      @event_registration = EventRegistration.new
      @event_registration.errors.add(:base, "No participant found with that email address. Please register as a participant first.")
      render :new, status: :unprocessable_entity
      return
    end

    @event_registration = @event.event_registrations.build(participant: participant)

    if @event_registration.save
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
end
