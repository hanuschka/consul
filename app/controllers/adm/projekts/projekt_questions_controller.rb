class Adm::Projekts::ProjektQuestionsController < Adm::Projekts::BaseController
  before_action :set_projekt_phase
  before_action :set_projekt_question, only: %i[edit update destroy]

  def new
    @projekt_question = @projekt_phase.questions.new
    @projekt_question.projekt_livestream_id = params[:projekt_livestream_id]
    authorize [:adm, :projekts, @projekt_question]

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @projekt_question = @projekt_phase.questions.new(projekt_question_params)
    @projekt_question.author = current_user
    authorize [:adm, :projekts, @projekt_question]

    if @projekt_question.save
      redirect_to redirect_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_questions.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize [:adm, :projekts, @projekt_question]

    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @projekt_question]

    if @projekt_question.update(projekt_question_params)
      redirect_to redirect_path, notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.projekt_questions.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @projekt_question]

    @projekt_question.destroy!
    redirect_to redirect_path, notice: t(".success")
  end

  def send_notifications
    authorize @projekt_phase, :update?, policy_class: Adm::Projekts::ProjektPhasePolicy

    NotificationServices::ProjektQuestionsNotifier.call(@projekt_phase.id)
    redirect_to projekt_questions_adm_projekts_phase_path(@projekt_phase), notice: t(".success")
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_projekt_question
      @projekt_question = ProjektQuestion.find(params[:id])
    end

    def projekt_question_params
      params.require(:projekt_question).permit(
        :title, :comments_enabled, :show_answers_count, :projekt_livestream_id,
        question_options_attributes: [:id, :_destroy, :value]
      )
    end

    def redirect_path
      livestream = @projekt_question.projekt_livestream
      if livestream.present?
        adm_projekts_phase_projekt_livestream_path(@projekt_phase, livestream)
      else
        projekt_questions_adm_projekts_phase_path(@projekt_phase)
      end
    end

    def breadcrumbs_for_action(action_title)
      livestream = @projekt_question&.projekt_livestream
      if livestream.present?
        [
          { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t("adm.projekts.phases.projekt_livestreams.title"), url: projekt_livestreams_adm_projekts_phase_path(@projekt_phase) },
          { name: livestream.title, url: adm_projekts_phase_projekt_livestream_path(@projekt_phase, livestream) },
          { name: action_title }
        ]
      else
        [
          { name: @projekt_phase.projekt.page.title, url: details_adm_projekts_projekt_path(@projekt_phase.projekt) },
          { name: @projekt_phase.title },
          { name: t("adm.projekts.phases.projekt_questions.title"), url: projekt_questions_adm_projekts_phase_path(@projekt_phase) },
          { name: action_title }
        ]
      end
    end
end
