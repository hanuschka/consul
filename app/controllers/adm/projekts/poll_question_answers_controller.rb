class Adm::Projekts::PollQuestionAnswersController < Adm::Projekts::BaseController
  include ImageAttributes
  include DocumentAttributes

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

    if @answer.update(answer_params)
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
      @answer.destroy!
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
        { name: t("adm.menu.items.projekts"), url: adm_projekts_root_path },
        { name: @projekt_phase.projekt.name, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.poll_questions.title"), url: poll_questions_adm_projekts_phase_path(@projekt_phase) },
        { name: @question.title, url: adm_projekts_phase_poll_question_path(@projekt_phase, @question) },
        { name: action_title }
      ]
    end
end
