class ProjektManagement::ProjektEventRegistrationsController < ProjektManagement::BaseController
  def index
    projekt_event = ProjektEvent.find(params[:projekt_event_id])
    registrations = projekt_event.projekt_event_registrations.order(:created_at)

    respond_to do |format|
      format.csv do
        send_data CsvServices::ProjektEventRegistrationsExporter.call(registrations),
                  filename: "registrations-#{projekt_event.title.parameterize}-#{Date.today}.csv"
      end
    end
  end

  def destroy
    @projekt_event = ProjektEvent.find(params[:projekt_event_id])
    registration = @projekt_event.projekt_event_registrations.find(params[:id])

    registration.destroy
    redirect_back fallback_location: projekt_management_root_path,
                  notice: t("custom.admin.projekt_phases.projekt_events.registration_deleted")
  end
end
