class Adm::Projekts::PollQuestionAnswersController < Adm::Projekts::BaseController
  include ImageAttributes
  include DocumentAttributes
  include Adm::ContextedClonesRegeneration

  before_action :set_projekt_phase
  before_action :set_question
  before_action :set_answer, only: %i[edit update destroy]

  def new
    @answer = Poll::Question::Answer.new
    @answer.videos.build

    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def create
    @answer = Poll::Question::Answer.new(answer_params)
    @answer.question = @question
    @answer.given_order = Poll::Question::Answer.last_position(@question.id) + 1

    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy

    if @answer.save
      regenerate_contexted_clones_for(@question, *@question.contextualized_dependents)

      redirect_to adm_projekts_phase_poll_question_path(@projekt_phase, @question),
        notice: t(".success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.poll_question_answers.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @answer.videos.build unless @answer.videos.any?

    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy
    @breadcrumbs = breadcrumbs_for_action(t(".title"))
  end

  def update
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy

    if locked_title_change?
      @answer.assign_attributes(answer_params)
      flash.now[:error] = t(".error")
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.poll_question_answers.edit.title"))

      return render :edit, status: :unprocessable_entity
    end

    if @answer.update(answer_params)
      regenerate_contexted_clones_for(@question, *@question.contextualized_dependents)

      redirect_to adm_projekts_phase_poll_question_path(@projekt_phase, @question),
        notice: t("adm.attribute.update.success")
    else
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.poll_question_answers.edit.title"))
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy

    if @question.poll.safe_to_delete_answer?
      # Clones of questions contextualised by this one reference this answer via
      # context_id, so drop them before deleting the answer, then rebuild.
      dependents = @question.contextualized_dependents.to_a
      dependents.each { |dependent| dependent.contexted_clones.each(&:really_destroy!) }
      @answer.destroy!
      # Reload so regeneration doesn't re-destroy the now-stale clone objects
      # already removed above.
      regenerate_contexted_clones_for(@question, *dependents.map(&:reload))

      redirect_to adm_projekts_phase_poll_question_path(@projekt_phase, @question),
        notice: t(".success")
    else
      redirect_to adm_projekts_phase_poll_question_path(@projekt_phase, @question),
        flash: { error: t(".error") }
    end
  end

  def order_answers
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy
    ordered_ids = params[:tree].map { |item| item[:id] }
    Poll::Question::Answer.order_answers(ordered_ids)
    head :ok
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_question
      @question = @projekt_phase.poll.questions.find(params[:poll_question_id])
    end

    def set_answer
      @answer = @question.question_answers.find(params[:id])
    end

    def locked_title_change?
      return false if @question.poll.safe_to_delete_answer?

      submitted_title = answer_params[:title]

      submitted_title.present? && submitted_title != @answer.title
    end

    def answer_params
      params.require(:poll_question_answer).permit(
        :title, :description, :given_order, :question_id,
        :open_answer, :more_info_link, :more_info_iframe,
        :next_question_id, :terminates_poll,
        images_attributes: image_attributes,
        documents_attributes: [document_attributes],
        videos_attributes: [:title, :url, :id, :_destroy]
      )
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.poll_questions.title"), url: poll_questions_adm_projekts_phase_path(@projekt_phase) },
        { name: @question.title, url: adm_projekts_phase_poll_question_path(@projekt_phase, @question) },
        { name: action_title }
      ]
    end
end
