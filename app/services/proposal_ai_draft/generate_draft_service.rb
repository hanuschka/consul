class ProposalAiDraft::GenerateDraftService < ApplicationService
  # The chat path. A phase that offers categories or sentiments requires them
  # at create (Labelable, Sentimentable), and the bot has no form to fall back
  # to — so the schema forces a valid choice, and anything a schema cannot
  # force falls to a question in the chat. The web keeps the plain .call:
  # there the model may decline and a human picks from the form's own
  # selector.
  def self.with_required_taxonomy(idea_text:, projekt_phase:)
    new(idea_text: idea_text, projekt_phase: projekt_phase, taxonomy_choice: :required).call
  end

  def initialize(idea_text:, projekt_phase:, taxonomy_choice: :optional)
    @idea_text = idea_text
    @projekt_phase = projekt_phase
    @taxonomy_choice = taxonomy_choice
  end

  def call
    projekt_name = @projekt_phase.projekt.page.title
    system_instructions = build_system_instructions(projekt_name)
    user_prompt = build_user_prompt(projekt_name)

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema, feature: "proposal_ai_draft.generate_draft")
        .with_instructions(system_instructions)
        .ask(user_prompt)

    normalized_content(response.content)
  rescue StandardError => e
    Rails.logger.error("[ProposalAiDraft] GenerateDraftService failed: #{e.class} - #{e.message}")
    Rails.logger.error("[ProposalAiDraft] Backtrace: #{e.backtrace.first(10).join("\n")}")
    raise e
  end

  private

    def fetch_system_prompt
      parsed_response = DtApi::Client.new(use_cache: true).consul_ai_prompts.get(:proposal_generate_with_ai).parsed_response
      parsed_response.dig("consul_ai_prompt", "prompt")
    end

    def build_system_instructions(projekt_name)
      system_prompt = fetch_system_prompt
      raise "[ProposalAiDraft] System prompt not found for proposal_generate_with_ai" if system_prompt.nil?

      system_prompt.gsub("{{projekt_name}}", projekt_name)
    end

    def build_user_prompt(projekt_name)
      <<~PROMPT
        Project name: #{projekt_name}

        The citizen described their idea as:
        "#{@idea_text}"
        #{taxonomy_prompt_section}#{submission_slots_prompt_section}
      PROMPT
    end

    # Carried in the user prompt because the system prompt is not ours to edit:
    # build_system_instructions fetches it over DtApi from the consul_ai_prompts
    # store, so anything the local schema asks for has to be explained locally or
    # it is asked for with no instruction behind it.
    def submission_slots_prompt_section
      return "" if !required_taxonomy?

      <<~SECTION

        This idea arrived by chat, where the photo and the location are asked for one after the
        other in later messages. Report whether the citizen already settled either of them in
        the message above, so they are not asked again for something they have already said.
        Judge only their words: when they did not mention it, the answer is false.
      SECTION
    end

    def taxonomy_prompt_section
      sections = []
      sections << sentiments_prompt_section if available_sentiments.any?
      sections << labels_prompt_section if available_labels.any?

      return "" if sections.empty?

      "\n\n" + sections.join("\n\n")
    end

    def sentiments_prompt_section
      options = available_sentiments.map { |sentiment| "- #{sentiment.id}: #{sentiment.name}" }.join("\n")

      "Available sentiments (#{sentiment_choice_instruction}):\n#{options}"
    end

    def labels_prompt_section
      options = available_labels.map { |label| "- #{label.id}: #{label.name}" }.join("\n")

      "Available categories (#{label_choice_instruction}):\n#{options}"
    end

    def required_taxonomy?
      @taxonomy_choice == :required
    end

    # Collapses the required mode's two label keys back into the canonical
    # projekt_label_ids every reader already uses, so the split is invisible
    # outside the schema.
    def normalized_content(content)
      draft_data = content.to_h

      return draft_data if !draft_data.key?("projekt_label_id")

      primary_label_id = draft_data.delete("projekt_label_id")
      additional_label_ids = Array(draft_data.delete("additional_projekt_label_ids"))

      draft_data["projekt_label_ids"] =
        ([primary_label_id] + additional_label_ids).map(&:to_i).uniq

      draft_data
    end

    def sentiment_choice_instruction
      if required_taxonomy?
        "you must choose the single closest-fitting id, even when none fits well"
      else
        "choose the single best-matching id, or null if none fit"
      end
    end

    def label_choice_instruction
      if required_taxonomy?
        "choose the single best-fitting id, even when none fits well, " \
          "plus the ids of any further categories that also clearly apply"
      else
        "choose the ids of all that clearly apply, or an empty array if none fit"
      end
    end

    # In required mode the options come from the same policies every
    # downstream validator reads (Whatsapp::DraftTaxonomy), so the model can
    # only be offered ids the create validation will accept. The optional/web
    # mode keeps its own broader read: the form's selector shows
    # projekt_labels, and its controller filters against the same set.
    def available_sentiments
      @available_sentiments ||=
        if required_taxonomy?
          ::Whatsapp::DraftTaxonomy.sentiment(@projekt_phase).options
        elsif @projekt_phase.feature?("form.sentiments")
          @projekt_phase.sentiments.includes(:translations).to_a
        else
          []
        end
    end

    def available_labels
      @available_labels ||=
        if required_taxonomy?
          ::Whatsapp::DraftTaxonomy.category(@projekt_phase).options
        elsif @projekt_phase.feature?("form.labels")
          @projekt_phase.projekt_labels.includes(:translations).to_a
        else
          []
        end
    end

    # The two questions the chat flow asks after the draft, answered here when the
    # citizen already answered them unasked. Someone who writes "eine Idee zum
    # Projekt Radwege: mehr Fahrradbügel am Bahnhof, ein Foto habe ich nicht" was
    # still asked for a photo and a location afterwards, one message each
    # (CON-2982).
    #
    # Confined to the required-taxonomy path, which is the chat's. The web's
    # `.call` shares this service but not its steps — it has a form, where every
    # field is on screen at once and nothing is asked in sequence — and its
    # system prompt is fetched from the remote consul_ai_prompts store, so a
    # property added to its schema is one nothing has told the model about. Every
    # property here is required, so that would be a demand with no instruction
    # behind it.
    SUBMISSION_SLOT_KEYS = %w[photo_declined location_stated].freeze

    def output_schema
      properties = base_schema_properties
      required = properties.keys.map(&:to_s)

      if required_taxonomy?
        properties[:photo_declined] = photo_declined_schema
        properties[:location_stated] = location_stated_schema
        required.push(*SUBMISSION_SLOT_KEYS)
      end

      if available_sentiments.any?
        properties[:sentiment_id] = sentiment_schema
        required << "sentiment_id"
      end

      if available_labels.any?
        if required_taxonomy?
          properties[:projekt_label_id] = primary_label_schema
          properties[:additional_projekt_label_ids] = additional_labels_schema
          required << "projekt_label_id" << "additional_projekt_label_ids"
        else
          properties[:projekt_label_ids] = labels_schema
          required << "projekt_label_ids"
        end
      end

      {
        type: "object",
        properties: properties,
        required: required,
        additionalProperties: false
      }
    end

    # Read strictly off what the citizen wrote, never inferred from the subject
    # matter: a proposal about a photo exhibition does not mean they declined to
    # send one, and skipping a question they never answered is worse than asking
    # it. Both default false, which is the flow exactly as it behaved before.
    def photo_declined_schema
      {
        type: "boolean",
        description: "True only if the citizen's own words say they have no photo or do not " \
                     "want to send one (\"ein Foto habe ich nicht\", \"ohne Bild\"). False " \
                     "whenever they did not mention a photo at all. Never infer this from " \
                     "what the proposal is about."
      }
    end

    def location_stated_schema
      {
        type: "boolean",
        description: "True only if the citizen named where this is, in their own words (\"am " \
                     "Bahnhof\", \"Hauptstraße 14\", \"im Stadtpark\"), or said there is no " \
                     "particular place. False whenever they did not say where. Never infer " \
                     "this from the projekt's own name or area."
      }
    end

    def sentiment_schema
      if required_taxonomy?
        {
          type: "integer",
          enum: available_sentiments.map(&:id),
          description: "The id of the single closest-fitting sentiment from the provided " \
                       "list. One has to be chosen, even when none fits well."
        }
      else
        {
          type: ["integer", "null"],
          enum: available_sentiments.map(&:id) + [nil],
          description: "The id of the single most fitting sentiment for the proposal from " \
                       "the provided list, or null if none apply."
        }
      end
    end

    # The required mode splits the labels into a forced single choice plus an
    # optional remainder: a strict provider enforces "integer from this enum"
    # but has no way to enforce a non-empty array (minItems is not supported),
    # so the scalar is the only shape that guarantees at least one valid label.
    def primary_label_schema
      {
        type: "integer",
        enum: available_labels.map(&:id),
        description: "The id of the single closest-fitting category from the provided " \
                     "list. One has to be chosen, even when none fits well."
      }
    end

    def additional_labels_schema
      {
        type: "array",
        items: { type: "integer", enum: available_labels.map(&:id) },
        description: "Ids of any further categories that also clearly apply. Empty " \
                     "array when only the one fits."
      }
    end

    def labels_schema
      {
        type: "array",
        items: { type: "integer", enum: available_labels.map(&:id) },
        description: "Ids of the most relevant categories for the proposal from the " \
                     "provided list. Empty array if none apply."
      }
    end

    def base_schema_properties
      {
        title: {
          type: "string",
          description: "A concise, compelling title for the citizen proposal."
        },
        description: {
          type: "string",
          description: "A detailed description of the proposal explaining the problem, solution, and " \
                       "expected impact. Should be written in HTML format, starting directly with a <p> " \
                       "paragraph. Must not repeat or restate the title and must not begin with a heading."
        },
        tag_list: {
          type: "string",
          description: "A comma-separated list of relevant tags categorizing the proposal topic."
        },
        image_prompt: {
          type: "string",
          description: "A descriptive prompt for generating a representative image for the proposal. Should be vivid and specific."
        },
        location: {
          type: ["string", "null"],
          description: "The geographic location relevant to the proposal (e.g. street, district, city). Null if not location-specific."
        },
        card_summary: {
          type: "string",
          description: "The description shortened to at most 700 characters of plain text (no " \
                       "HTML), for a chat preview card. Whole sentences that end properly, in " \
                       "the description's own language, saying only what the description says " \
                       "— what is asked for and where. When the description is already that " \
                       "short, the same text without markup."
        }
      }
    end
end
