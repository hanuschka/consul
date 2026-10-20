class Api::PollQuestionsController < Api::BaseController
  include Translatable

  DEFAULT_QUESTIONS_PER_PAGE = 100

  before_action :find_poll, only: [:index, :create]
  before_action :find_question, only: [:show, :update, :destroy]

  def index
    check_read_access!

    questions = paginate(
      @poll.questions
        .includes(:question_answers)
        .order(given_order: :asc, created_at: :asc),
      default_per_page: DEFAULT_QUESTIONS_PER_PAGE
    )

    serialized_questions = Poll::QuestionSerializer.serialize_collection(questions)

    render json: {
      data: { questions: serialized_questions },
      pagination: pagination_meta(questions)
    }
  end

  def create
    check_admin_access!

    question = @poll.questions.new(question_params)
    question.author = User.administrators.first
    question.votation_type ||= VotationType.new(vote_type: :unique)
    question.given_order ||= @poll.questions.maximum(:given_order).to_i + 1

    if question.save
      serialized_question = Poll::QuestionSerializer.new(question).serialize

      render json: { data: { question: serialized_question }}, status: :created
    else
      render json: { error: { messages: question.errors.full_messages }}, status: :unprocessable_entity
    end
  end

  def show
    check_read_access!

    serialized_question = Poll::QuestionSerializer.new(@question).serialize

    render json: { data: { question: serialized_question }}
  end

  def update
    check_admin_access!

    inject_votation_type_id

    if @question.update(question_params)
      serialized_question = Poll::QuestionSerializer.new(@question).serialize

      render json: { data: { question: serialized_question }}
    else
      render json: { error: { messages: @question.errors.full_messages }}, status: :unprocessable_entity
    end
  end

  def destroy
    check_admin_access!

    if @question.destroy
      render json: { message: "Poll question destroyed" }
    else
      render json: { error: { messages: @question.errors.messages }}, status: :unprocessable_entity
    end
  end

  private

    def question_params
      params.require(:question).permit(
        :title,
        :description,
        :intro,
        :multiple,
        :given_order,
        :show_images,
        :answer_mandatory,
        :bundle_question,
        :parent_question_id,
        :randomize_answers,
        :randomize_position,
        translation_params(Poll::Question, only: [:title, :description, :intro]),
        votation_type_attributes: [:id, :vote_type, :max_votes, :max_votes_per_answer, :show_hint_callout]
      )
    end

    def find_poll
      @poll = Poll.find(params[:poll_id])
    end

    def find_question
      @question = Poll::Question.includes(:question_answers).find(params[:id])
    end

    def inject_votation_type_id
      return if params.dig(:question, :votation_type_attributes).blank?
      return if @question.votation_type.blank?

      params[:question][:votation_type_attributes][:id] = @question.votation_type.id
    end
end
