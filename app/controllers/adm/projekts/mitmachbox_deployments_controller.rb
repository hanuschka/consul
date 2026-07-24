class Adm::Projekts::MitmachboxDeploymentsController < Adm::Projekts::BaseController
  include Adm::Projekts::MitmachboxErrorHandling

  before_action :set_projekt_phase
  before_action :authorize_phase
  before_action :ensure_remote_survey
  before_action :set_deployment, only: %i[edit update destroy]

  def new
    @assignments = selectable_assignments
    @deployment = { "assignment_id" => params[:assignment_id] }
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    mitmachbox_client.deployments.create(
      assignment_id: params.require(:deployment)[:assignment_id],
      survey_id: @projekt_phase.mitmachbox_survey_id,
      location: params.require(:deployment)[:location].presence
    )

    redirect_to deployments_tab_path, notice: t("adm.projekts.mitmachbox.deployments.created")
  end

  def edit
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    mitmachbox_client.deployments.update(
      @deployment["id"],
      location: params.require(:deployment)[:location].presence
    )

    redirect_to deployments_tab_path, notice: t("adm.projekts.mitmachbox.deployments.updated")
  end

  def destroy
    mitmachbox_client.deployments.delete(@deployment["id"])

    redirect_to deployments_tab_path, notice: t("adm.projekts.mitmachbox.deployments.ended")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def authorize_phase
      authorize @projekt_phase, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy
    end

    def ensure_remote_survey
      unless Mitmachbox.configured? && @projekt_phase.remote_survey_created?
        redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase)
      end
    end

    # Authorization is per phase, but the deployments API is org-wide. Reject
    # any deployment that doesn't belong to this phase's survey so a manager
    # can't edit/end another projekt's deployment by guessing its id.
    def set_deployment
      @deployment = mitmachbox_client.deployments.find(params[:id])

      unless @deployment["survey_id"].to_s == @projekt_phase.mitmachbox_survey_id.to_s
        redirect_to deployments_tab_path, alert: t("adm.projekts.mitmachbox.errors.not_found")
      end
    end

    def mitmachbox_error_redirect_path
      deployments_tab_path
    end

    def selectable_assignments
      mitmachbox_fetch_all { |page, per_page| mitmachbox_client.assignments.list(page: page, per_page: per_page) }
        .reject { |assignment| assignment["status"] == "ended" }
    end

    def deployments_tab_path
      mitmachbox_deployments_adm_projekts_phase_path(@projekt_phase)
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.mitmachbox_deployments.title"), url: deployments_tab_path },
        { name: action_title }
      ]
    end
end
