class Api::PollQuestionAnswersController < Api::BaseController
  include Translatable
  include DocumentAttributes

  DEFAULT_ANSWERS_PER_PAGE = 100

  TRANSLATED_ATTRIBUTES = Poll::Question::AnswerSerializer::TRANSLATED_ATTRIBUTES

  before_action :find_question, only: [:index, :create, :order_answers]
  before_action :find_answer, only: [:show, :update, :destroy]

  def index
    check_read_access!
    check_phase_visible!(@question.poll.projekt_phase)

    answers = paginate(
      @question.question_answers.order(given_order: :asc),
      default_per_page: DEFAULT_ANSWERS_PER_PAGE
    )

    serialized_answers = Poll::Question::AnswerSerializer.serialize_collection(
      answers,
      vote_totals: poll_vote_totals(@question.poll, [@question.id])
    )

    render json: {
      data: { answers: serialized_answers },
      pagination: pagination_meta(answers)
    }
  end

  def create
    check_admin_access!

    answer = @question.question_answers.new(answer_params)
    answer.given_order = Poll::Question::Answer.last_position(@question.id) + 1
    assign_attachment_authors(answer)
    translations = assign_requested_translations(answer, :answer, TRANSLATED_ATTRIBUTES)

    if save_with_translations(answer, translations)
      regenerate_contexted_clones(@question)

      render json: { data: { answer: serialize_answer(answer) }}, status: :created
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(answer) }}, status: :unprocessable_entity
    end
  end

  def show
    check_read_access!
    check_phase_visible!(@answer.question.poll.projekt_phase)

    render json: { data: { answer: serialize_answer(@answer) }}
  end

  def update
    check_admin_access!

    @answer.assign_attributes(answer_params)
    assign_attachment_authors(@answer)
    translations = assign_requested_translations(@answer, :answer, TRANSLATED_ATTRIBUTES)

    if locked_title_change?(@answer)
      return render json: {
        error: { messages: ["The poll has votes, so its answer titles can no longer change."] }
      }, status: :unprocessable_entity
    end

    if save_with_translations(@answer, translations)
      regenerate_contexted_clones(@answer.question)

      render json: { data: { answer: serialize_answer(@answer) }}
    else
      render json: { error: { messages: TranslatedRecordErrors.full_messages(@answer) }}, status: :unprocessable_entity
    end
  end

  # Clones of the questions contextualised by this one reference the answer
  # through context_id, so they go first and are rebuilt afterwards, as in
  # /adm.
  def destroy
    check_admin_access!

    question = @answer.question

    if !question.poll.safe_to_delete_answer?
      return render json: {
        error: { messages: ["The poll has votes, so its answers can no longer be deleted."] }
      }, status: :unprocessable_entity
    end

    Poll::Question::Answer.transaction do
      question.contextualized_dependents.each do |dependent|
        dependent.contexted_clones.each(&:really_destroy!)
      end

      @answer.destroy!
    end

    regenerate_contexted_clones(question)

    render json: { message: "Poll question answer destroyed" }
  end

  def order_answers
    check_admin_access!

    Poll::Question::Answer.order_answers(params[:ordered_list])

    render json: { message: "Answers reordered" }
  end

  private

    def answer_params
      @answer_params ||= with_decoded_images(
        with_decoded_documents(
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
            videos_attributes: [:id, :title, :url, :_destroy],
            images_attributes: [:id, :title, :attachment, :credits, :ai_generated, :_destroy],
            documents_attributes: document_attributes_api
          )
        )
      )
    end

    # Gallery images arrive base64 encoded like documents, which Active
    # Storage cannot take as they are.
    def with_decoded_images(answer_attributes)
      images = answer_attributes[:images_attributes]
      return answer_attributes if images.blank?

      image_list = images.is_a?(Array) ? images : images.values

      image_list.each do |image|
        encoded_file = image[:attachment]
        next if !encoded_file.is_a?(String) || encoded_file.blank?

        image[:attachment] = Base64Attachable.build(encoded_file, filename_stem: image[:title])
      end

      answer_attributes
    end

    # Files arrive without an author: the API never lets a client choose
    # whom a file is attributed to.
    def assign_attachment_authors(answer)
      assign_document_authors(answer)

      answer.images.select(&:new_record?).each do |image|
        image.user = current_client.content_author
      end
    end

    # Questions contextualised by this one are rebuilt from its answers, as
    # /adm does after every answer change, unless the poll already has votes.
    # The reload drops the answers preloaded before the change.
    def regenerate_contexted_clones(question)
      question.reload

      [question, *question.contextualized_dependents].each(&:regenerate_contexted_clones_if_safe)
    end

    # Once the poll has votes, renaming an option would change what people
    # voted for; /adm blocks it the same way. New languages stay allowed.
    def locked_title_change?(answer)
      title_changed =
        answer.translations.select(&:persisted?).any? do |translation|
          translation.title_changed? ||
            answer.globalize.changes(translation.locale.to_sym).key?("title")
        end

      title_changed && !answer.question.poll.safe_to_delete_answer?
    end

    def serialize_answer(answer)
      Poll::Question::AnswerSerializer.new(
        answer,
        vote_totals: poll_vote_totals(answer.question.poll, [answer.question_id])
      ).serialize
    end

    def find_question
      @question =
        Poll::Question
          .includes(:question_answers, poll: :projekt_phase)
          .find(params[:poll_question_id])
    end

    def find_answer
      @answer =
        Poll::Question::Answer
          .includes(question: [:question_answers, { poll: :projekt_phase }])
          .find(params[:id])
    end
end
