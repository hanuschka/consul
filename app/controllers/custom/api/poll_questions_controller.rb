class Api::PollQuestionsController < Api::BaseController
  include Translatable
  include MapLocationAttributes

  DEFAULT_QUESTIONS_PER_PAGE = 100

  TRANSLATED_ATTRIBUTES = Poll::QuestionSerializer::TRANSLATED_ATTRIBUTES
  RATING_LABEL_ATTRIBUTES = Poll::QuestionSerializer::RATING_LABEL_ATTRIBUTES

  before_action :find_poll, only: [:index, :create]
  before_action :find_question, only: [:show, :update, :destroy]

  def index
    check_read_access!
    check_phase_visible!(@poll.projekt_phase)

    questions = paginate(
      @poll.questions
        .preload(Poll::QuestionSerializer::PRELOADS)
        .order(given_order: :asc, created_at: :asc),
      default_per_page: DEFAULT_QUESTIONS_PER_PAGE
    )

    serialized_questions = Poll::QuestionSerializer.serialize_collection(
      questions,
      vote_totals: poll_vote_totals(@poll, questions.map(&:id))
    )

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
    translations = assign_question_translations(question)

    if save_with_translations(question, translations)
      question.regenerate_contexted_clones_if_safe

      render json: { data: { question: serialize_question(question) }}, status: :created
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(question) }}, status: :unprocessable_entity
    end
  end

  def show
    check_read_access!
    check_phase_visible!(@question.poll.projekt_phase)

    render json: { data: { question: serialize_question(@question) }}
  end

  def update
    check_admin_access!

    inject_votation_type_id
    @question.assign_attributes(question_params)
    translations = assign_question_translations(@question)

    if save_with_translations(@question, translations)
      @question.regenerate_contexted_clones_if_safe

      render json: { data: { question: serialize_question(@question) }}
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(@question) }}, status: :unprocessable_entity
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
        :contextualize_by_poll_question_id,
        :randomize_answers,
        :randomize_position,
        translation_params(Poll::Question, only: [:title, :description, :intro]),
        votation_type_attributes: [
          :id, :vote_type, :max_votes, :max_votes_per_answer, :show_hint_callout,
          :min_rating_scale_label, :max_rating_scale_label
        ],
        map_location_attributes: map_location_attributes_api
      )
    end

    # The question's own texts and the rating scale labels, which live on its
    # votation type, are written per language in the same request.
    def assign_question_translations(question)
      translations = assign_requested_translations(question, :question, TRANSLATED_ATTRIBUTES)
      label_translations_param = params.dig(:question, :votation_type_attributes, :translations)
      locales_error = unsupported_locales_error(label_translations_param)

      if locales_error.present?
        raise UnsupportedLocalesError, locales_error.transform_keys { "votation_type_attributes.#{it}" }
      end

      label_translations = permitted_translations(label_translations_param, RATING_LABEL_ATTRIBUTES)

      if label_translations.any? && question.votation_type.present?
        assign_translations(question.votation_type, label_translations)
      end

      translations.merge(label_translations) { |_locale, texts, labels| texts.merge(labels) }
    end

    def serialize_question(question)
      Poll::QuestionSerializer.new(
        question,
        vote_totals: poll_vote_totals(question.poll, [question.id])
      ).serialize
    end

    def find_poll
      @poll = Poll.includes(:projekt_phase).find(params[:poll_id])
    end

    def find_question
      @question =
        Poll::Question
          .includes(Poll::QuestionSerializer::PRELOADS, poll: :projekt_phase)
          .find(params[:id])
    end

    def inject_votation_type_id
      return if params.dig(:question, :votation_type_attributes).blank?
      return if @question.votation_type.blank?

      params[:question][:votation_type_attributes][:id] = @question.votation_type.id
    end
end
