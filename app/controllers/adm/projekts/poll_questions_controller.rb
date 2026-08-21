class Adm::Projekts::PollQuestionsController < Adm::Projekts::BaseController
  include Adm::ContextedClonesRegeneration

  before_action :set_projekt_phase
  before_action :set_poll
  before_action :set_question, only: %i[show edit update destroy]

  def new
    @question = Poll::Question.new(poll: @poll)
    @question.votation_type = VotationType.new
    @question.parent_question = Poll::Question.find(params[:parent_question_id]) if params[:parent_question_id].present?

    authorize [:adm, :projekts, @question], :create?, policy_class: Adm::Projekts::PollQuestionPolicy
    set_context_sources
    @title = if params[:parent_question_id].present?
                t(".nested_title")
              elsif params[:bundle_question] == "true"
                t(".bundle_title")
              else
                t(".title")
              end
    @breadcrumbs = breadcrumbs_for_action(@title)
  end

  def create
    @question = Poll::Question.new(question_params)
    @question.poll = @poll
    @question.author = current_user

    authorize [:adm, :projekts, @question], :create?, policy_class: Adm::Projekts::PollQuestionPolicy

    @question.votation_type ||= VotationType.new(vote_type: :unique)
    @question.given_order = @poll.questions.maximum(:given_order).to_i + 1

    if @question.save
      regenerate_contexted_clones_for(@question)

      redirect_path = if @question.parent_question.present?
                        adm_projekts_phase_poll_question_path(@projekt_phase, @question.parent_question)
                      else
                        adm_projekts_phase_poll_question_path(@projekt_phase, @question)
                      end
      redirect_to redirect_path
    else
      set_context_sources
      @breadcrumbs = breadcrumbs_for_action(t("adm.projekts.poll_questions.new.title"))
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy
    @breadcrumbs = breadcrumbs_for_action(@question.title)
  end

  def edit
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy
    set_context_sources
    @title = edit_title
    @breadcrumbs = breadcrumbs_for_action(@title)
  end

  def update
    authorize [:adm, :projekts, @question], :update?, policy_class: Adm::Projekts::PollQuestionPolicy

    if @question.update(question_params)
      regenerate_contexted_clones_for(@question)

      redirect_path = if @question.parent_question.present?
                        adm_projekts_phase_poll_question_path(@projekt_phase, @question.parent_question)
                      else
                        poll_questions_adm_projekts_phase_path(@projekt_phase)
                      end
      redirect_to redirect_path, notice: t("adm.attribute.update.success")
    else
      set_context_sources
      @title = edit_title
      @breadcrumbs = breadcrumbs_for_action(@title)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize [:adm, :projekts, @question], :destroy?, policy_class: Adm::Projekts::PollQuestionPolicy

    @question.destroy!

    redirect_path =
      if @question.parent_question.present?
        adm_projekts_phase_poll_question_path(@projekt_phase, @question.parent_question)
      else
        poll_questions_adm_projekts_phase_path(@projekt_phase)
      end

    redirect_to redirect_path, notice: t(".success")
  end

  def order_questions
    authorize [:adm, :projekts, @poll], :update?
    ordered_ids = params[:tree].map { |item| item[:id] }
    ::Poll::Question.order_questions(ordered_ids)
    head :ok
  end

  private

    def set_projekt_phase
      @projekt_phase = ProjektPhase.find(params[:phase_id])
    end

    def set_poll
      @poll = @projekt_phase.poll
    end

    def set_question
      @question = @poll.questions.find(params[:id])
    end

    def set_context_sources
      @context_sources = @poll.questions
        .where.not(id: @question.id)
        .where(contextualize_by_poll_question_id: nil)
        .joins(:votation_type)
        .where(votation_types: { vote_type: :multiple })
    end

    def question_params
      params.require(:poll_question).permit(
        :poll_id,
        :title,
        :description,
        :intro,
        :proposal_id,
        :show_images,
        :parent_question_id,
        :bundle_question,
        :answer_mandatory,
        :randomize_answers,
        :randomize_position,
        :contextualize_by_poll_question_id,
        votation_type_attributes: [
          :id, :vote_type, :max_votes, :max_votes_per_answer,
          :show_hint_callout, :min_rating_scale_label, :max_rating_scale_label
        ]
      )
    end

    def edit_title
      if @question.parent_question.present?
        t("adm.projekts.poll_questions.edit.nested_title")
      elsif @question.bundle_question?
        t("adm.projekts.poll_questions.edit.bundle_title")
      else
        t("adm.projekts.poll_questions.edit.title")
      end
    end

    def breadcrumbs_for_action(action_title)
      [
        { name: @projekt_phase.projekt.page.title, url: phases_adm_projekts_projekt_path(@projekt_phase.projekt) },
        { name: @projekt_phase.title },
        { name: t("adm.projekts.phases.poll_questions.title"), url: poll_questions_adm_projekts_phase_path(@projekt_phase) },
        { name: action_title }
      ]
    end
end
