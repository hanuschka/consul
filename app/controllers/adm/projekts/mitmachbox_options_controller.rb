class Adm::Projekts::MitmachboxOptionsController < Adm::Projekts::BaseController
  include Adm::Projekts::MitmachboxErrorHandling

  MAX_OPTIONS_PER_QUESTION = 5

  before_action :set_projekt_phase
  before_action :authorize_phase
  before_action :set_survey_and_draft
  before_action :set_question
  before_action :set_option, only: %i[edit update destroy]

  def new
    @option = {}
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    if @question["options"].size >= MAX_OPTIONS_PER_QUESTION
      redirect_to question_path, alert: t("adm.projekts.mitmachbox.errors.max_options_reached") and return
    end

    mitmachbox_client.options.create(survey_id, draft_id, @question["id"], **option_params)

    redirect_to question_path, notice: t("adm.projekts.mitmachbox.options.created")
  end

  def edit
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    mitmachbox_client.options.update(survey_id, draft_id, @question["id"], @option["id"], option_params)

    redirect_to question_path, notice: t("adm.projekts.mitmachbox.options.updated")
  end

  def destroy
    mitmachbox_client.options.delete(survey_id, draft_id, @question["id"], @option["id"])

    redirect_to question_path, notice: t("adm.projekts.mitmachbox.options.destroyed")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def authorize_phase
      authorize @projekt_phase, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy
    end

    def set_survey_and_draft
      unless Mitmachbox.configured? && @projekt_phase.remote_survey_created?
        redirect_to survey_tab_path and return
      end

      @survey = mitmachbox_client.surveys.find(@projekt_phase.mitmachbox_survey_id)

      if @survey["draft_version"].blank?
        redirect_to survey_tab_path, alert: t("adm.projekts.mitmachbox.errors.no_draft") and return
      end

      @draft_detail = mitmachbox_client.versions.find(survey_id, draft_id)
    end

    def set_question
      @question = @draft_detail["questions"].find { |question| question["id"].to_s == params[:mitmachbox_question_id].to_s }

      if @question.blank?
        redirect_to survey_tab_path, alert: t("adm.projekts.mitmachbox.errors.not_found")
      end
    end

    def set_option
      @option = @question["options"].find { |option| option["id"].to_s == params[:id].to_s }

      if @option.blank?
        redirect_to question_path, alert: t("adm.projekts.mitmachbox.errors.not_found")
      end
    end

    def survey_id
      @survey["id"]
    end

    def draft_id
      @survey["draft_version"]["id"]
    end

    def survey_tab_path
      mitmachbox_survey_adm_projekts_phase_path(@projekt_phase)
    end

    def question_path
      edit_adm_projekts_phase_mitmachbox_question_path(@projekt_phase, @question["id"])
    end

    def option_params
      permitted = params.require(:option).permit(:label, :value)

      {
        label: permitted[:label].to_s,
        value: permitted[:value].presence&.to_i
      }
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.mitmachbox_survey.title"), url: survey_tab_path },
        { name: @question["prompt"], url: question_path },
        { name: action_title }
      ]
    end
end
