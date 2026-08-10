class Api::PollQuestionAnswersController < Api::BaseController
  include Translatable

  DEFAULT_ANSWERS_PER_PAGE = 100

  before_action :find_question, only: [:index, :create, :order_answers]
  before_action :find_answer, only: [:show, :update, :destroy]

  def index
    check_read_access!

    answers = paginate(
      @question.question_answers.order(given_order: :asc),
      default_per_page: DEFAULT_ANSWERS_PER_PAGE
    )

    serialized_answers = Poll::Question::AnswerSerializer.serialize_collection(answers)

    render json: {
      data: { answers: serialized_answers },
      pagination: pagination_meta(answers)
    }
  end

  def create
    check_admin_access!

    answer = @question.question_answers.new(answer_params)
    answer.given_order = Poll::Question::Answer.last_position(@question.id) + 1

    if answer.save
      serialized_answer = Poll::Question::AnswerSerializer.new(answer).serialize

      render json: { data: { answer: serialized_answer }}, status: :created
    else
      render json: { error: { messages: answer.errors.full_messages }}, status: :unprocessable_entity
    end
  end

  def show
    check_read_access!

    serialized_answer = Poll::Question::AnswerSerializer.new(@answer).serialize

    render json: { data: { answer: serialized_answer }}
  end

  def update
    check_admin_access!

    if @answer.update(answer_params)
      serialized_answer = Poll::Question::AnswerSerializer.new(@answer).serialize

      render json: { data: { answer: serialized_answer }}
    else
      render json: { error: { messages: @answer.errors.full_messages }}, status: :unprocessable_entity
    end
  end

  def destroy
    check_admin_access!

    if @answer.destroy
      render json: { message: "Poll question answer destroyed" }
    else
      render json: { error: { messages: @answer.errors.messages }}, status: :unprocessable_entity
    end
  end

  def order_answers
    check_admin_access!

    Poll::Question::Answer.order_answers(params[:ordered_list])

    render json: { message: "Answers reordered" }
  end

  private

    def answer_params
      params.require(:answer).permit(
        :title,
        :description,
        :given_order,
        :open_answer,
        :more_info_link,
        :more_info_iframe,
        :next_question_id,
        :terminates_poll,
        translation_params(Poll::Question::Answer, only: [:title, :description]),
        videos_attributes: [:id, :title, :url, :_destroy]
      )
    end

    def find_question
      @question = Poll::Question.find(params[:poll_question_id])
    end

    def find_answer
      @answer = Poll::Question::Answer.find(params[:id])
    end
end
