class Whatsapp::AiAssistant::TaxonomyRetryService < ApplicationService
  # The drafting call is handed the phase's categories and sentiments as closed
  # enums in the same request that writes the title, and it still comes back
  # without a usable one often enough that CompleteDraftService has a question
  # waiting. That question is a whole extra round trip for the citizen, over a
  # choice the model was already given everything it needed to make.
  #
  # So it is asked once more first, on its own, with what it answered before named
  # back to it. A second failure falls through to the citizen exactly as before —
  # this only removes the interruptions that were never necessary, and never adds
  # one.
  #
  # The fast model: one closed choice over a handful of labels, on a turn the
  # citizen is already waiting through.
  REQUEST_TIMEOUT_SECONDS = 15
  DESCRIPTION_PREVIEW_LENGTH = 600

  CATEGORY = :category
  SENTIMENT = :sentiment

  def initialize(requirement:, draft_data:, projekt_phase:)
    @requirement = requirement
    @draft_data = draft_data.to_h
    @projekt_phase = projekt_phase
  end

  # The ids under the key the draft data already uses, so the caller merges the
  # answer in and re-reads it through the same DraftCategory/DraftSentiment
  # validation that rejected the first one. Nil whenever nothing usable came
  # back, which is the caller's cue to ask the citizen.
  def call
    return if options.empty?
    return if !::Ai::Settings.ai_available?

    chosen
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] taxonomy retry failed: #{e.class} - #{e.message}")

    nil
  end

  private

    def options
      @options ||=
        if @requirement == CATEGORY
          ::Whatsapp::DraftCategory.options_for(@projekt_phase)
        else
          ::Whatsapp::DraftSentiment.options_for(@projekt_phase)
        end
    end

    # Validated here as well as by the caller, because the two answer different
    # questions: this one drops an id the model invented, the caller's re-reads the
    # phase in case the option was removed between the two calls.
    def chosen
      permitted_ids = options.map(&:id)

      return category_ids(permitted_ids) if @requirement == CATEGORY

      sentiment_id(permitted_ids)
    end

    def category_ids(permitted_ids)
      ids = Array(response_content["projekt_label_ids"]).map(&:to_i) & permitted_ids

      return if ids.empty?

      { "projekt_label_ids" => ids }
    end

    def sentiment_id(permitted_ids)
      id = response_content["sentiment_id"].to_i

      return if !permitted_ids.include?(id)

      { "sentiment_id" => id }
    end

    def response_content
      @response_content ||=
        ::Ai::RubyLlmFactory
          .fast_chat(REQUEST_TIMEOUT_SECONDS)
          .with_schema(output_schema)
          .with_instructions(instructions)
          .ask(user_prompt)
          .content
          .to_h
    end

    # Told that a choice is required rather than invited to make one: the first
    # call was allowed to answer "none of these fit", and the record cannot be
    # written on that answer. The closest fit is what the citizen would be asked
    # for anyway.
    def instructions
      <<~TEXT
        A citizen's contribution to a participation portal has been drafted, and one classification
        it needs is missing: the previous attempt either left it out or answered with something the
        portal does not offer.

        Choose from the listed options only, by id. One of them has to be chosen — the closest fit,
        even when none is a good one — because the contribution cannot be saved without it and the
        alternative is interrupting the citizen to ask. Never answer with an id that is not listed,
        and never answer with none.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The contribution:
        Title: "#{draft_title}"
        Text: "#{description_preview}"

        What the previous attempt answered for this: #{previous_answer.inspect}

        The options to choose from:
        #{option_lines}
      PROMPT
    end

    def previous_answer
      return @draft_data["projekt_label_ids"] if @requirement == CATEGORY

      @draft_data["sentiment_id"]
    end

    def draft_title
      @draft_data["title"]
    end

    def description_preview
      ::Whatsapp.plain_text(@draft_data["description"], length: DESCRIPTION_PREVIEW_LENGTH)
    end

    def option_lines
      options.map { |option| "- #{option.id}: #{option.name}" }.join("\n")
    end

    def output_schema
      return category_schema if @requirement == CATEGORY

      sentiment_schema
    end

    def category_schema
      {
        type: "object",
        properties: {
          projekt_label_ids: {
            type: "array",
            items: { type: "integer", enum: options.map(&:id) },
            description: "Ids of the categories that apply, at least one."
          }
        },
        required: %w[projekt_label_ids],
        additionalProperties: false
      }
    end

    def sentiment_schema
      {
        type: "object",
        properties: {
          sentiment_id: {
            type: "integer",
            enum: options.map(&:id),
            description: "Id of the single closest-fitting sentiment."
          }
        },
        required: %w[sentiment_id],
        additionalProperties: false
      }
    end
end
