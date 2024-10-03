module AdminActions::Poll::Questions
  extend ActiveSupport::Concern

  include CommentableActions
  include Translatable

  included do
    load_and_authorize_resource :poll
    load_resource class: "Poll::Question", except: [:order_questions]
    authorize_resource except: [:new, :create, :order_questions]
    skip_authorization_check only: :new
  end

  def index
    @polls = Poll.not_budget
    @questions = @questions.search(search_params).page(params[:page]).order("created_at DESC")

    @proposals = Proposal.successful.sort_by_confidence_score

    render "admin/poll/questions/index"
  end

  def new
    proposal = Proposal.find(params[:proposal_id]) if params[:proposal_id].present?
    @question.copy_attributes_from_proposal(proposal)
    @question.poll = @poll
    @question.votation_type = VotationType.new

    render "admin/poll/questions/new"
  end

  def create
    @question.author = @question.proposal&.author || current_user
    authorize! :create, @question

    if @question.votation_type.nil?
      @question.votation_type = VotationType.new(vote_type: :unique)
    end

    @question.given_order ||= @question.poll.questions.maximum(:given_order).to_i + 1

    if @question.save
      if @question.bundle_question?
        redirect_to polymorphic_path([@namespace, @question])
      else
        redirect_to polymorphic_path([@namespace, @question.poll, @question], action: :edit_votation_type)
      end
    else
      render "admin/poll/questions/new"
    end
  end

  def show
    render "admin/poll/questions/show"
  end

  def edit
    render "admin/poll/questions/edit"
  end

  def update
    if @question.update(question_params)
      if @question.bundle_question?
        redirect_to polymorphic_path([@namespace, @question]), notice: t("flash.actions.save_changes.notice")
      else
        redirect_to polymorphic_path([@namespace, @question.poll, @question], action: :edit_votation_type), notice: t("flash.actions.save_changes.notice")
      end
    else
      render "admin/poll/questions/edit"
    end
  end

  def destroy
    @question.destroy!

    destroy_path =
      if @question.parent_question.present?
        polymorphic_path([@namespace, @question.parent_question])
      else
        polymorphic_path([@namespace, @question.poll.projekt_phase], action: :poll_questions)
      end

    redirect_to destroy_path, notice: t("admin.questions.destroy.notice")
  end

  def edit_votation_type; end

  def update_votation_type
    @votation_type = @question.votation_type

    if @votation_type.update(votation_type_params)
      redirect_to polymorphic_path([@namespace, @question.poll.projekt_phase], action: :poll_questions)
    else
      render "admin/poll/questions/edit_votation_type"
    end
  end

  def order_questions # custom
    ::Poll::Question.order_questions(params[:ordered_list])
    head :ok
  end

  private

    def question_params
      params.require(:poll_question).permit(
        :poll_id,
        :question,
        :proposal_id,
        :show_images,
        :parent_question_id,
        :bundle_question,
        :answer_mandatory,
        :next_question_id,
        translation_params(Poll::Question)
      )
    end

    def votation_type_params
      params.require(:votation_type).permit(
        :vote_type,
        :max_votes,
        :max_votes_per_answer,
        :show_hint_callout,
        translation_params(VotationType)
      )
    end

    def search_params
      params.permit(:poll_id, :search)
    end
end
