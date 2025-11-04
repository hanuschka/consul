class Api::QuestionsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:create]
  before_action :find_projekt_question, only: [:show, :update, :destroy]

  def create
    check_admin_access!
    projekt_question = @projekt_phase.questions.new(projekt_question_params)

    if projekt_question.save
      serialized_projekt_question = QuestionSerializer.new(projekt_question).serialize

      render json: { data: { projekt_question: serialized_projekt_question } }, status: 201
    else
      # Collect errors from both parent and nested translations
      all_errors = projekt_question.errors.full_messages
      projekt_question.translations.each do |translation|
        all_errors.concat(translation.errors.full_messages) if translation.errors.any?
      end
      
      render json: { error: { messages: all_errors } }, status: 422
    end
  end

  def show
    check_read_access!
    serialized_projekt_question = QuestionSerializer.new(@projekt_question).serialize

    render json: { data: { projekt_question: serialized_projekt_question } }
  end

  def update
    check_admin_access!
    @projekt_question.assign_attributes(projekt_question_params)
    
    # Validate translations before saving - Globalize may silently reject invalid translations
    # We need to check this because Globalize will reject invalid translations without failing the save
    translation_errors = []
    @projekt_question.translations.each do |translation|
      if translation.changed? && !translation.valid?
        translation_errors.concat(translation.errors.full_messages)
      end
    end
    
    if translation_errors.any? || !@projekt_question.save
      all_errors = translation_errors + @projekt_question.errors.full_messages
      @projekt_question.translations.each do |translation|
        all_errors.concat(translation.errors.full_messages) if translation.errors.any?
      end
      render json: { error: { messages: all_errors } }, status: 422
    else
      serialized_projekt_question = QuestionSerializer.new(@projekt_question).serialize

      render json: { data: { projekt_question: serialized_projekt_question } }
    end
  end

  def destroy
    check_admin_access!
    if @projekt_question.destroy
      render json: { message: "Projekt question destroyed" }
    else
      render json: { error: { messages: @projekt_question.errors.messages } }, status: 422
    end
  end

  private

  def projekt_question_params
    params.require(:projekt_question).permit(
      :projekt_livestream_id,
      **translation_params(ProjektQuestion),
      question_options_attributes: [:id, :_destroy, translations_attributes: [:id, :locale, :value, :_destroy]]
    )
  end

  def find_projekt_phase
    # Questions can be in QuestionPhase or LivestreamPhase
    phase_type = params[:phase_type] || "ProjektPhase::QuestionPhase"
    @projekt_phase = phase_type.constantize.find(params[:projekt_phase_id])
  end

  def find_projekt_question
    @projekt_question = ProjektQuestion.find(params[:id])
  end
end

