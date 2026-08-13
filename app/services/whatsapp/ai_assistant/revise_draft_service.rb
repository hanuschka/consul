class Whatsapp::AiAssistant::ReviseDraftService < ApplicationService
  # A revision used to be a regeneration: the citizen's correction was glued to
  # the end of their original idea and the whole draft written again from the
  # pair. "Mach den Titel kürzer" therefore arrived as more idea text, and the
  # description the citizen had already approved was rewritten along with the
  # title they asked about — every round drifting further from what they read and
  # agreed to.
  #
  # This asks for an edit instead. Every field is nullable, null means "leave it",
  # and only what comes back non-null is applied.
  #
  # The full model rather than the fast one used by the router and the classifier:
  # what this writes is what gets published, at the same bar as the first draft.
  # The prompt is local rather than fetched from the DT API like
  # ProposalAiDraft::GenerateDraftService's — there is no revise prompt on that
  # side to fetch, and this loop exists only in the chat.
  def initialize(resource:, correction:, projekt_phase:)
    @resource = resource
    @correction = correction.to_s.strip
    @projekt_phase = projekt_phase
  end

  # A complete draft_data hash, not only what changed:
  # Whatsapp::Drafting::PersistDraftService writes every field it reads, so a
  # hash missing the title would blank the title on the record.
  def call
    current_draft_data.merge(applied_changes)
  end

  private

    # Null is how the model says "leave this as it is", so a null must not reach
    # the merge: merged as nil it would blank the very field it meant to keep. An
    # empty label list says the same thing and is dropped by the same rule.
    def applied_changes
      response_content.select { |_field, value| value.present? }
    end

    # What the record already holds, so a field the correction did not touch
    # survives the merge unchanged.
    #
    # image_prompt is carried rather than offered for rewriting: by the time a
    # revision is possible the picture may already have been generated from it,
    # and a new prompt would describe an image nobody is going to produce.
    #
    # location is deliberately absent. PersistDraftService geocodes whatever it
    # finds under that key, so carrying the old name forward would re-geocode the
    # same place on every revision — while a new one coming back from the model is
    # exactly the case that should.
    def current_draft_data
      {
        "title" => @resource.title,
        "description" => @resource.description,
        "tag_list" => @resource.tag_list.to_s,
        "image_prompt" => @resource.ai_image_prompt
      }.merge(current_taxonomy)
    end

    # Only for the phases that offer them: a key the phase has no taxonomy for is
    # discarded by DraftSentiment.valid_id and DraftCategory.valid_ids anyway, and
    # asking the record for a column its resource may not carry is worse than not
    # asking.
    def current_taxonomy
      chosen_sentiment = sentiments.any? ? { "sentiment_id" => @resource.sentiment_id } : {}
      chosen_labels = labels.any? ? { "projekt_label_ids" => @resource.projekt_label_ids } : {}

      chosen_sentiment.merge(chosen_labels)
    end

    def response_content
      ::Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(instructions)
        .ask(user_prompt)
        .content
        .to_h
    end

    def instructions
      <<~TEXT
        You revise one draft contribution to a citizen participation portal. The citizen was shown
        the draft below, written from their own idea, and has asked for a change to it. Apply that
        change and nothing else.

        Rules:
        - Return null for every field the change does not touch. Null means "leave this exactly as
          it is", and it is the right answer for most fields on most corrections.
        - Never rewrite what they did not ask about. A change to the title is not a reason to touch
          the description, nor the other way round.
        - Keep their subject, their place and what they are asking for. You are editing their
          contribution, not writing a better one of your own.
        - Write in the language the draft is written in.
        - The description is HTML and starts directly with a <p> paragraph. It must not repeat the
          title and must not begin with a heading.
        - Return a location only when the change names a different place than the draft does.
        - When the change is not about the contribution at all, return null for every field.
      TEXT
    end

    def user_prompt
      <<~PROMPT
        The current draft:
        Title: "#{@resource.title}"
        Description: "#{@resource.description}"
        Tags: "#{@resource.tag_list}"
        #{taxonomy_prompt_section}

        The change the citizen asked for:
        "#{@correction}"
      PROMPT
    end

    def taxonomy_prompt_section
      [sentiments_prompt_section, labels_prompt_section].compact_blank.join("\n\n")
    end

    def sentiments_prompt_section
      return if sentiments.empty?

      options = sentiments.map { |sentiment| "- #{sentiment.id}: #{sentiment.name}" }.join("\n")

      "Currently chosen sentiment id: #{@resource.sentiment_id.inspect}\n" \
        "Available sentiments:\n#{options}"
    end

    def labels_prompt_section
      return if labels.empty?

      options = labels.map { |label| "- #{label.id}: #{label.name}" }.join("\n")

      "Currently chosen category ids: #{@resource.projekt_label_ids.inspect}\n" \
        "Available categories:\n#{options}"
    end

    def sentiments
      @sentiments ||= ::Whatsapp::DraftSentiment.options_for(@projekt_phase)
    end

    def labels
      @labels ||= ::Whatsapp::DraftCategory.options_for(@projekt_phase)
    end

    def output_schema
      properties = base_schema_properties.merge(taxonomy_schema_properties)

      {
        type: "object",
        properties: properties,
        required: properties.keys.map(&:to_s),
        additionalProperties: false
      }
    end

    def base_schema_properties
      {
        title: {
          type: ["string", "null"],
          description: "The revised title, or null to keep the current one."
        },
        description: {
          type: ["string", "null"],
          description: "The revised description as HTML starting with a <p> paragraph, or null " \
                       "to keep the current one. Must not repeat the title."
        },
        tag_list: {
          type: ["string", "null"],
          description: "A comma-separated list of tags, or null to keep the current ones. Only " \
                       "when the change makes the current tags wrong."
        },
        location: {
          type: ["string", "null"],
          description: "The place the contribution is about, only when the change names a " \
                       "different one than the draft does. Null otherwise."
        }
      }
    end

    def taxonomy_schema_properties
      sentiment_property = sentiments.any? ? { sentiment_id: sentiment_schema } : {}
      labels_property = labels.any? ? { projekt_label_ids: labels_schema } : {}

      sentiment_property.merge(labels_property)
    end

    def sentiment_schema
      {
        type: ["integer", "null"],
        enum: sentiments.map(&:id) + [nil],
        description: "The id of the fitting sentiment, only when the change makes the current " \
                     "one wrong. Null otherwise."
      }
    end

    def labels_schema
      {
        type: ["array", "null"],
        items: { type: "integer", enum: labels.map(&:id) },
        description: "Ids of the fitting categories, only when the change makes the current ones " \
                     "wrong. Null otherwise."
      }
    end
end
