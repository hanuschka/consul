class ProjektEventRegistrationsController < ApplicationController
  skip_authorization_check

  before_action :set_projekt_event, except: [:confirm]

  def create
    registration = @projekt_event.projekt_event_registrations.new(registration_params)
    registration.user = current_user if current_user

    unless registration.email_requires_confirmation?(current_user)
      registration.skip_email_confirmation!
    end

    if registration.save
      if registration.pending_confirmation?
        Mailer.projekt_event_registration_confirmation_email(registration).deliver_later
        flash[:notice] = t("custom.projekt_events.registration.confirmation_email_sent")
      else
        track_registration(registration)
        Mailer.projekt_event_registration_email(registration).deliver_later

        if registration.status == "confirmed"
          flash[:notice] = t("custom.projekt_events.registration.confirmed")
        else
          flash[:notice] = t("custom.projekt_events.registration.waitlisted")
        end
      end
    else
      flash[:alert] = registration.errors.full_messages.first || t("custom.projekt_events.registration.error")
    end

    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path) }
      format.js { @projekt_event.reload }
    end
  end

  def confirm
    registration = ProjektEventRegistration.find_by!(confirmation_token: params[:token])
    @projekt_event = registration.projekt_event

    if registration.pending_confirmation?
      registration.confirm_email!
      track_registration(registration)
      Mailer.projekt_event_registration_email(registration).deliver_later

      if registration.status == "confirmed"
        flash[:notice] = t("custom.projekt_events.registration.confirmed")
      else
        flash[:notice] = t("custom.projekt_events.registration.waitlisted")
      end
    else
      flash[:notice] = t("custom.projekt_events.registration.already_confirmed")
    end

    redirect_back(fallback_location: root_path)
  rescue ActiveRecord::RecordNotFound
    flash[:alert] = t("custom.projekt_events.registration.invalid_token")
    redirect_to root_path
  end

  def destroy
    registration = @projekt_event.projekt_event_registrations.find(params[:id])

    if owned_registration?(registration)
      registration.destroy
      untrack_registration(registration)
      flash[:notice] = t("custom.projekt_events.registration.cancelled")
    else
      flash[:alert] = t("custom.projekt_events.registration.error")
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

    def registration_params
      params.require(:projekt_event_registration).permit(:first_name, :last_name, :email)
    end

    def owned_registration?(registration)
      if current_user
        registration.user_id == current_user.id
      else
        session_registration_ids.include?(registration.id)
      end
    end

    def track_registration(registration)
      return if current_user

      session[:registered_registration_ids] ||= []
      session[:registered_registration_ids] << registration.id
    end

    def untrack_registration(registration)
      return if current_user

      session[:registered_registration_ids]&.delete(registration.id)
    end

    def session_registration_ids
      Array(session[:registered_registration_ids])
    end
end
