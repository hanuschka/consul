class ProjektManagement::ProjektEventRegistrationsController < ProjektManagement::BaseController
  def destroy
    @projekt_event = ProjektEvent.find(params[:projekt_event_id])
    registration = @projekt_event.projekt_event_registrations.find(params[:id])

    registration.destroy
    redirect_back fallback_location: projekt_management_root_path,
                  notice: t("custom.admin.projekt_phases.projekt_events.registration_deleted")
  end
end
