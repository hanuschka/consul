class ProjektEventRegistrationsController < ApplicationController
  before_action :authenticate_user!, only: [:destroy]
  skip_authorization_check

  before_action :set_projekt_event

  def create
    if current_user
      registration = @projekt_event.projekt_event_registrations.new(user: current_user)
    elsif guest_registered?(@projekt_event.id)
      flash[:alert] = t("custom.projekt_events.registration.already_registered")
      return respond_to do |format|
        format.html { redirect_back(fallback_location: root_path) }
        format.js { @guest_registered_event_id = @projekt_event.id }
      end
    else
      registration = @projekt_event.projekt_event_registrations.new(guest_params)
    end

    if registration.save
      mark_guest_registered(@projekt_event.id) if registration.guest?
      if registration.status == "confirmed"
        flash[:notice] = t("custom.projekt_events.registration.confirmed")
      else
        flash[:notice] = t("custom.projekt_events.registration.waitlisted")
      end
    else
      flash[:alert] = t("custom.projekt_events.registration.error")
    end

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.js do
        @projekt_event.reload
        @guest_registered_event_id = registration.persisted? && registration.guest? ? @projekt_event.id : nil
      end
    end
  end

  def destroy
    registration = @projekt_event.registration_for(current_user)

    if registration
      registration.destroy
      flash[:notice] = t("custom.projekt_events.registration.cancelled")
    end

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.js { @projekt_event.reload }
    end
  end

  private

    def set_projekt_event
      @projekt_event = ProjektEvent.find(params[:projekt_event_id])
    end

    def guest_params
      params.require(:projekt_event_registration).permit(:first_name, :last_name, :email)
    end

    def guest_registered?(event_id)
      Array(session[:guest_registered_event_ids]).include?(event_id)
    end

    def mark_guest_registered(event_id)
      session[:guest_registered_event_ids] ||= []
      session[:guest_registered_event_ids] << event_id
    end
end
