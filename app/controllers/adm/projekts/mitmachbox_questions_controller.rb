class Adm::Projekts::MitmachboxQuestionsController < Adm::Projekts::BaseController
  include Adm::Projekts::MitmachboxErrorHandling

  QUESTION_TYPES = %w[single_choice multiple_choice rating].freeze

  before_action :set_projekt_phase
  before_action :authorize_phase
  before_action :set_survey_and_draft
  before_action :set_question, only: %i[edit update destroy move_up move_down]

  def new
    @question = {}
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    mitmachbox_client.questions.create(survey_id, draft_id, **question_params)

    redirect_to survey_tab_path, notice: t("adm.projekts.mitmachbox.questions.created")
  end

  def edit
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    mitmachbox_client.questions.update(survey_id, draft_id, @question["id"], question_params)

    redirect_to survey_tab_path, notice: t("adm.projekts.mitmachbox.questions.updated")
  end

  def destroy
    mitmachbox_client.questions.delete(survey_id, draft_id, @question["id"])

    redirect_to survey_tab_path, notice: t("adm.projekts.mitmachbox.questions.destroyed")
  end

  def move_up
    reorder_question(-1)
  end

  def move_down
    reorder_question(1)
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
      @question = @draft_detail["questions"].find { |question| question["id"].to_s == params[:id].to_s }

      if @question.blank?
        redirect_to survey_tab_path, alert: t("adm.projekts.mitmachbox.errors.not_found")
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

    def question_params
      permitted = params.require(:question).permit(:prompt, :question_type, :required)
      question_type = permitted[:question_type].presence_in(QUESTION_TYPES) || "single_choice"

      {
        prompt: permitted[:prompt].to_s,
        question_type: question_type,
        required: permitted[:required] == "1"
      }
    end

    def reorder_question(offset)
      ordered_ids = @draft_detail["questions"].sort_by { |question| question["position"] }.map { |question| question["id"] }
      index = ordered_ids.index(@question["id"])
      target_index = index + offset

      if target_index.between?(0, ordered_ids.size - 1)
        ordered_ids[index], ordered_ids[target_index] = ordered_ids[target_index], ordered_ids[index]
        mitmachbox_client.questions.reorder(survey_id, draft_id, question_ids: ordered_ids)
      end

      redirect_to survey_tab_path
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.mitmachbox_survey.title"), url: survey_tab_path },
        { name: action_title }
      ]
    end
end
