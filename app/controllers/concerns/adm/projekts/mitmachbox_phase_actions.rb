# The Mitmachbox tabs of a phase (survey authoring/lifecycle, device
# deployments, results) — extracted from PhasesController, which routes all
# phase tabs as member actions.
module Adm::Projekts::MitmachboxPhaseActions
  extend ActiveSupport::Concern
  include Adm::Projekts::MitmachboxErrorHandling

  def mitmachbox_survey
    authorize_phase(:update?)
    @breadcrumbs = mitmachbox_breadcrumbs(t(".title"))

    return unless Mitmachbox.configured? && @projekt_phase.remote_survey_created?

    begin
      @survey = mitmachbox_client.surveys.find(@projekt_phase.mitmachbox_survey_id)
      version_ref = @survey["draft_version"] || @survey["current_version"]
      @version_detail = version_ref && mitmachbox_client.versions.find(@survey["id"], version_ref["id"])
    rescue Mitmachbox::NotFoundError
      @survey_lost = true
    rescue Mitmachbox::Error => e
      @mitmachbox_error = e
    end
  end

  def mitmachbox_create_survey
    authorize_phase(:update?)
    @projekt_phase.update_columns(mitmachbox_survey_id: nil) if params[:reset].present?
    Mitmachbox::CreateRemoteSurveyService.call(projekt_phase: @projekt_phase, acting_user: current_user)

    redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
      notice: t("adm.projekts.mitmachbox.survey.created")
  end

  def mitmachbox_survey_state
    authorize_phase(:update?)
    state = params[:state]

    unless %w[draft open closed archived].include?(state)
      redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
        alert: t("adm.projekts.mitmachbox.errors.generic") and return
    end

    mitmachbox_client.surveys.update_state(@projekt_phase.mitmachbox_survey_id, state)

    redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
      notice: t("adm.projekts.mitmachbox.survey.state_changed", state: t("adm.projekts.mitmachbox.survey.states.#{state}"))
  end

  def mitmachbox_create_draft
    authorize_phase(:update?)
    mitmachbox_client.versions.create(@projekt_phase.mitmachbox_survey_id)

    redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
      notice: t("adm.projekts.mitmachbox.survey.draft_created")
  end

  def mitmachbox_publish_draft
    authorize_phase(:update?)
    survey = mitmachbox_client.surveys.find(@projekt_phase.mitmachbox_survey_id)
    draft = survey["draft_version"]

    if draft.blank?
      redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
        alert: t("adm.projekts.mitmachbox.errors.no_draft") and return
    end

    mitmachbox_client.versions.publish(survey["id"], draft["id"])

    redirect_to mitmachbox_survey_adm_projekts_phase_path(@projekt_phase),
      notice: t("adm.projekts.mitmachbox.survey.published")
  end

  def mitmachbox_deployments
    authorize_phase(:update?)
    @breadcrumbs = mitmachbox_breadcrumbs(t(".title"))

    return unless Mitmachbox.configured? && @projekt_phase.remote_survey_created?

    begin
      @assignments = mitmachbox_fetch_all { |page, per_page| mitmachbox_client.assignments.list(page: page, per_page: per_page) }
      # All org deployments, not just this survey's — the devices table needs to
      # know what each box is currently showing.
      @all_deployments = mitmachbox_fetch_all do |page, per_page|
        mitmachbox_client.deployments.list(page: page, per_page: per_page)
      end
      @deployments = @all_deployments.select do |deployment|
        deployment["survey_id"].to_s == @projekt_phase.mitmachbox_survey_id.to_s
      end
    rescue Mitmachbox::Error => e
      @mitmachbox_error = e
    end
  end

  def mitmachbox_results
    authorize_phase(:update?)
    @breadcrumbs = mitmachbox_breadcrumbs(t(".title"))

    return unless Mitmachbox.configured? && @projekt_phase.remote_survey_created?

    begin
      @results = mitmachbox_client.results.find(@projekt_phase.mitmachbox_survey_id)
    rescue Mitmachbox::Error => e
      @mitmachbox_error = e
    end
  end

  def mitmachbox_results_export
    authorize_phase(:update?)
    csv = mitmachbox_client.results.export_csv(@projekt_phase.mitmachbox_survey_id)

    send_data csv,
      filename: "mitmachbox-ergebnisse-#{@projekt_phase.id}-#{Time.zone.today}.csv",
      type: "text/csv"
  end

  private

    def mitmachbox_breadcrumbs(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: action_title }
      ]
    end

    def create_mitmachbox_remote_survey
      return unless Mitmachbox.configured?

      Mitmachbox::CreateRemoteSurveyService.call(projekt_phase: @projekt_phase, acting_user: current_user)
    rescue Mitmachbox::Error => e
      Rails.logger.warn("[Mitmachbox] remote survey creation deferred for phase #{@projekt_phase.id}: #{e.message}")
    end
end
