class Adm::Projekts::ProjektEventRegistrationsController < Adm::Projekts::BaseController
  ALL_STATUSES = %w[confirmed waitlisted pending_confirmation cancelled].freeze

  skip_after_action :verify_policy_scoped, only: :index

  before_action :set_projekt_phase
  before_action :set_projekt_event
  before_action :set_registration, only: %i[destroy resend_confirmation]
  before_action :authorize_event

  def index
    scope = @projekt_event.projekt_event_registrations
      .order(Arel.sql("array_position(ARRAY['confirmed','waitlisted','pending_confirmation','cancelled']::text[], status::text)"))
      .order(:created_at)
    selected_statuses = Array(params[:status]) & ALL_STATUSES
    filtered_scope = selected_statuses.any? ? scope.where(status: selected_statuses) : scope

    respond_to do |format|
      format.html do
        @pagy, @registrations = pagy(filtered_scope)
        @status_header_options = { filter_options: status_filter_options }

        @breadcrumbs = breadcrumbs_for_action(t(".title"))
      end

      format.csv do
        send_data CsvServices::ProjektEventRegistrationsExporter.call(filtered_scope),
                  filename: "registrations-#{@projekt_event.title.parameterize}-#{Date.today}.csv"
      end
    end
  end

  def destroy
    @registration.destroy!
    redirect_to redirect_path, notice: t(".success")
  end

  def resend_confirmation
    if @registration.pending_confirmation?
      Mailer.projekt_event_registration_confirmation_email(@registration).deliver_later
      redirect_to redirect_path, notice: t(".success")
    else
      redirect_to redirect_path, alert: t(".not_pending")
    end
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_event
      @projekt_event = @projekt_phase.projekt_events.find(params[:projekt_event_id])
    end

    def set_registration
      @registration = @projekt_event.projekt_event_registrations.find(params[:id])
    end

    def authorize_event
      authorize @projekt_event, :update?, policy_class: Adm::Projekts::ProjektEventPolicy
    end

    def status_filter_options
      ALL_STATUSES.map do |status|
        [status, t("adm.projekts.projekt_event_registrations.index.statuses.#{status}")]
      end
    end

    def redirect_path
      adm_projekts_phase_projekt_event_registrations_path(
        @projekt_phase, @projekt_event, status: Array(params[:status]).presence
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.projekt_events.title"), url: projekt_events_adm_projekts_phase_path(@projekt_phase) },
        { name: @projekt_event.title, url: edit_adm_projekts_phase_projekt_event_path(@projekt_phase, @projekt_event) },
        { name: action_title }
      ]
    end
end
