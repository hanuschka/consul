class Api::QuestionOptionsController < Api::BaseController
  include Translatable

  TRANSLATED_ATTRIBUTES = %w[value].freeze

  before_action :find_projekt_question, only: [:index, :create]
  before_action :find_question_option, only: [:show, :update, :destroy]

  def index
    check_read_access!
    check_phase_visible!(@projekt_question.projekt_phase)

    question_options = paginate(
      @projekt_question.question_options.includes(:translations, question: :translations)
    )
    serialized_options = QuestionOptionSerializer.serialize_collection(question_options, client: current_client)

    render json: {
      data: { question_options: serialized_options },
      pagination: pagination_meta(question_options)
    }
  end

  def create
    check_admin_access!

    question_option = @projekt_question.question_options.new(
      question_option_params
    )
    translations = assign_requested_translations(question_option, :question_option, TRANSLATED_ATTRIBUTES)

    if save_with_translations(question_option, translations)
      serialized_option = QuestionOptionSerializer.new(question_option, client: current_client).serialize

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
    check_phase_visible!(@question_option.question.projekt_phase)

    serialized_option = QuestionOptionSerializer.new(@question_option, client: current_client).serialize

    render json: { data: { question_option: serialized_option } }
  end

  def update
    check_admin_access!
    @question_option.assign_attributes(question_option_params)
    translations = assign_requested_translations(@question_option, :question_option, TRANSLATED_ATTRIBUTES)

    translation_errors = []
    @question_option.translations.each do |translation|
      if translation.changed? && !translation.valid?
        translation_errors.concat(translation.errors.full_messages)
      end
    end

    if translation_errors.any? || !save_with_translations(@question_option, translations)
      all_errors = translation_errors + @question_option.errors.full_messages
      @question_option.translations.each do |translation|
        all_errors.concat(translation.errors.full_messages) if translation.errors.any?
      end
      render json: { error: { messages: all_errors } }, status: 422
    else
      serialized_option = QuestionOptionSerializer.new(@question_option, client: current_client).serialize

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
    @question_option = ProjektQuestionOption.includes(:translations, question: :translations).find(params[:id])
  end
end
