class PollQuestionImports::ApplyService < ApplicationService
  BOOLEAN_TYPE = ActiveModel::Type::Boolean.new

  attr_reader :question_import, :questions_attributes

  def initialize(question_import:, questions_attributes:)
    @question_import = question_import
    @questions_attributes = questions_attributes
  end

  def call
    phase = question_import.projekt_phase

    # A voting phase scaffolds its poll on create, but the poll is paranoid and
    # can be soft-deleted from /admin without the phase, leaving the phase
    # pollless. PollBuilder's own fallback cannot recover from that.
    if phase.poll.blank?
      return ServiceResult.failure(
        error: I18n.t("adm.projekts.poll_question_imports.errors.poll_missing")
      )
    end

    payload = build_payload

    if payload.empty?
      return ServiceResult.failure(
        error: I18n.t("adm.projekts.poll_question_imports.errors.nothing_selected")
      )
    end

    questions = create_questions(phase, payload)

    ServiceResult.success(questions: questions)
  rescue StandardError => e
    Rails.logger.error("[PollQuestionImports::ApplyService] failed: #{e.message}")

    if !e.is_a?(::ProjektImports::Builders::BuilderError) && defined?(Sentry)
      Sentry.capture_exception(e, extra: { poll_question_import_id: question_import.id })
    end

    ServiceResult.failure(
      error: I18n.t("adm.projekts.poll_question_imports.errors.apply_failed", message: e.message)
    )
  end

  private

    # One transaction for the whole apply: PollBuilder saves each question,
    # votation type and answer separately, so without this every record pays
    # its own BEGIN/COMMIT.
    #
    # The generated text is written in one language, so it must land in that
    # locale's translation rather than in whatever locale the admin happens to
    # be browsing in.
    def create_questions(phase, payload)
      ActiveRecord::Base.transaction do
        questions = I18n.with_locale(question_import.import_locale) do
          ::ProjektImports::Builders::PollBuilder.call(
            projekt: phase.projekt,
            phase: phase,
            payload: payload,
            author: question_import.author
          )
        end

        question_import.mark_applied!(questions)

        questions
      end
    end

    # fields_for-style params arrive as a hash keyed by index rather than an
    # array, so the values have to be read out before iterating.
    def indexed_values(value)
      return [] if value.blank?

      value.values
    end

    def build_payload
      indexed_values(questions_attributes).filter_map do |attributes|
        next if !included?(attributes)

        {
          "title" => attributes["title"].to_s.strip,
          "description" => attributes["description"].to_s.strip.presence,
          "vote_type" => attributes["vote_type"].to_s,
          "min_rating_scale_label" => attributes["min_rating_scale_label"].to_s.strip.presence,
          "max_rating_scale_label" => attributes["max_rating_scale_label"].to_s.strip.presence,
          "answers" => build_answers(attributes["answers"])
        }
      end
    end

    def included?(attributes)
      BOOLEAN_TYPE.cast(attributes["include"]).present?
    end

    # A cleared answer title is how the admin removes an answer in the preview --
    # PollBuilder drops blank-titled answers, so nothing else is needed.
    def build_answers(answers_attributes)
      indexed_values(answers_attributes).map do |answer|
        {
          "title" => answer["title"].to_s.strip,
          "description" => answer["description"].to_s.strip
        }
      end
    end
end
