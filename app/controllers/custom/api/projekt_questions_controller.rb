class Api::ProjektQuestionsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:create]
  before_action :find_projekt_question, only: [:show, :update, :destroy]

  def create
    projekt_question = @projekt_phase.questions.new(projekt_question_params)

    if projekt_question.save
      serialized_projekt_question = ProjektQuestionSerializer.new(projekt_question).serialize

      render json: { data: { projekt_question: serialized_projekt_question } }, status: 201
    else
      render json: { error: { messages: projekt_question.errors.full_messages } }, status: 422
    end
  end

  def show
    serialized_projekt_question = ProjektQuestionSerializer.new(@projekt_question).serialize

    render json: { data: { projekt_question: serialized_projekt_question } }
  end

  def update
    if @projekt_question.update(projekt_question_params)
      serialized_projekt_question = ProjektQuestionSerializer.new(@projekt_question).serialize

      render json: { data: { projekt_question: serialized_projekt_question } }
    else
      render json: { error: { messages: @projekt_question.errors.full_messages } }, status: 422
    end
  end

  def destroy
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
      *translation_params(ProjektQuestion),
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

