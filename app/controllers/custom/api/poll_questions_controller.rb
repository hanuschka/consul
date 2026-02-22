class Api::PollQuestionsController < Api::BaseController
  include Translatable

  before_action :find_poll, only: [:index, :create]
  before_action :find_question, only: [:show, :update, :destroy]

  def index
    check_read_access!

    questions = @poll.questions
      .includes(:question_answers)
      .order(given_order: :asc, created_at: :asc)

    serialized_questions = Poll::QuestionSerializer.serialize_collection(questions)

    render json: { data: { questions: serialized_questions } }
  end

  def create
    check_admin_access!

    question = @poll.questions.new(question_params)
    question.author = User.administrators.first

    if question.save
      serialized_question = Poll::QuestionSerializer.new(question).serialize

      render json: { data: { question: serialized_question } }, status: 201
    else
      render json: { error: { messages: question.errors.full_messages } }, status: 422
    end
  end

  def show
    check_read_access!

    serialized_question = Poll::QuestionSerializer.new(@question).serialize

    render json: { data: { question: serialized_question } }
  end

  def update
    check_admin_access!

    if @question.update(question_params)
      serialized_question = Poll::QuestionSerializer.new(@question).serialize

      render json: { data: { question: serialized_question } }
    else
      render json: { error: { messages: @question.errors.full_messages } }, status: 422
    end
  end

  def destroy
    check_admin_access!

    if @question.destroy
      render json: { message: "Poll question destroyed" }
    else
      render json: { error: { messages: @question.errors.messages } }, status: 422
    end
  end

  private

  def question_params
    params.require(:question).permit(
      :title,
      :multiple,
      :given_order,
      translation_params(Poll::Question, only: [:title])
    )
  end

  def find_poll
    @poll = Poll.find(params[:poll_id])
  end

  def find_question
    @question = Poll::Question.includes(:question_answers).find(params[:id])
  end
end
