class Api::QuestionOptionsController < Api::BaseController
  include Translatable

  before_action :find_projekt_question, only: [:create]
  before_action :find_question_option, only: [:show, :update, :destroy]

  def create
    check_admin_access!

    question_option = @projekt_question.question_options.new(
      question_option_params
    )

    if question_option.save
      serialized_option = QuestionOptionSerializer.new(question_option).serialize

      render json: { data: { question_option: serialized_option } }, status: 201
    else
      all_errors = question_option.errors.full_messages
      question_option.translations.each do |translation|
        all_errors.concat(translation.errors.full_messages) if translation.errors.any?
      end

      render json: { error: { messages: all_errors } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_option = QuestionOptionSerializer.new(@question_option).serialize

    render json: { data: { question_option: serialized_option } }
  end

  def update
    check_admin_access!
    @question_option.assign_attributes(question_option_params)

    translation_errors = []
    @question_option.translations.each do |translation|
      if translation.changed? && !translation.valid?
        translation_errors.concat(translation.errors.full_messages)
      end
    end

    if translation_errors.any? || !@question_option.save
      all_errors = translation_errors + @question_option.errors.full_messages
      @question_option.translations.each do |translation|
        all_errors.concat(translation.errors.full_messages) if translation.errors.any?
      end
      render json: { error: { messages: all_errors } }, status: 422
    else
      serialized_option = QuestionOptionSerializer.new(@question_option).serialize

      render json: { data: { question_option: serialized_option } }
    end
  end

  def destroy
    check_admin_access!
    if @question_option.destroy
      render json: { message: "Question option destroyed" }
    else
      render json: { error: { messages: @question_option.errors.messages } }, status: 422
    end
  end

  private

  def question_option_params
    params.require(:question_option).permit(:value)
  end

  def find_projekt_question
    @projekt_question = ProjektQuestion.find(params[:question_id])
  end

  def find_question_option
    @question_option = ProjektQuestionOption.find(params[:id])
  end
end
