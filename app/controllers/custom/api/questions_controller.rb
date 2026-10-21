class Api::QuestionsController < Api::BaseController
  include Translatable

  before_action :find_projekt_phase, only: [:index, :create], if: -> { params[:projekt_phase_id].present? }
  before_action :find_projekt_livestream_for_create, only: [:create]
  before_action :find_projekt_question, only: [:show, :update, :destroy]

  def index
    check_read_access!

    if @projekt_phase.present?
      if current_client.public_data?
        unless @projekt_phase.frontend_visibility && @projekt_phase.active?
          return render json: { error: { type: 'forbidden', messages: ['Access denied'] } }, status: 403
        end
      end

      questions = @projekt_phase.questions
        .includes(:projekt_phase, :projekt_livestream, :author)
    else
      questions = ProjektQuestion.includes(:projekt_phase, :projekt_livestream, :author)

      if current_client.public_data?
        questions = questions.joins(:projekt_phase)
          .where(projekt_phases: { frontend_visibility: true, active: true })
          .distinct
      end
    end

    questions = paginate(questions.order(created_at: :asc))

    serialized_questions = QuestionSerializer.serialize_collection(questions)

    render json: {
      data: { questions: serialized_questions },
      pagination: pagination_meta(questions)
    }
  end

  def create
    check_admin_access!
    find_projekt_phase unless @projekt_phase.present?

    projekt_question =
      if @projekt_livestream.present?
        question = @projekt_livestream.projekt_questions.build(projekt_question_params)
        question.projekt_phase = @projekt_livestream.projekt_phase

        question
      elsif @projekt_phase.present?
        @projekt_phase.questions.new(projekt_question_params)
      end

    projekt_question.author = current_client.content_author

    if projekt_question.save
      serialized_projekt_question = QuestionSerializer.new(projekt_question).serialize

      render json: { data: { projekt_question: serialized_projekt_question } }, status: 201
    else
      render json: { error: { messages: projekt_question.errors.full_messages } }, status: 422
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
      :title,
      :description,
      :projekt_livestream_id
    )
  end

  def find_projekt_phase
    if params[:projekt_phase_id].present?
      @projekt_phase = ProjektPhase.find_by(id: params[:projekt_phase_id])
    end
  end

  def find_projekt_livestream_for_create
    if params[:livestream_id].present?
      @projekt_livestream = ProjektLivestream.find_by(id: params[:livestream_id])

      return render json: {
        error: { messages: ["Projekt livestream not found"] }
      }, status: 404 unless @projekt_livestream.present?
    end
  end

  def find_projekt_question
    @projekt_question = ProjektQuestion.find(params[:id])
  end
end

