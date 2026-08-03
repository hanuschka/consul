class ProposalAiDraft::GenerateDraftService < ApplicationService
  def initialize(idea_text:, projekt_phase:)
    @idea_text = idea_text
    @projekt_phase = projekt_phase
  end

  def call
    projekt_name = @projekt_phase.projekt.page.title
    system_instructions = build_system_instructions(projekt_name)
    user_prompt = build_user_prompt(projekt_name)

    response =
      Ai::RubyLlmFactory
        .chat_with_json_output(output_schema)
        .with_instructions(system_instructions)
        .ask(user_prompt)

    response.content
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
        #{taxonomy_prompt_section}
      PROMPT
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

      "Available sentiments (choose the single best-matching id, or null if none fit):\n#{options}"
    end

    def labels_prompt_section
      options = available_labels.map { |label| "- #{label.id}: #{label.name}" }.join("\n")

      "Available categories (choose the ids of all that clearly apply, or an empty array if none fit):\n#{options}"
    end

    def available_sentiments
      @available_sentiments ||=
        if @projekt_phase.feature?("form.sentiments")
          @projekt_phase.sentiments.includes(:translations).to_a
        else
          []
        end
    end

    def available_labels
      @available_labels ||=
        if @projekt_phase.feature?("form.labels")
          @projekt_phase.projekt_labels.includes(:translations).to_a
        else
          []
        end
    end

    def output_schema
      properties = base_schema_properties
      required = properties.keys.map(&:to_s)

      if available_sentiments.any?
        properties[:sentiment_id] = {
          type: ["integer", "null"],
          enum: available_sentiments.map(&:id) + [nil],
          description: "The id of the single most fitting sentiment for the proposal from the provided list, or null if none apply."
        }
        required << "sentiment_id"
      end

      if available_labels.any?
        properties[:projekt_label_ids] = {
          type: "array",
          items: { type: "integer", enum: available_labels.map(&:id) },
          description: "Ids of the most relevant categories for the proposal from the provided list. Empty array if none apply."
        }
        required << "projekt_label_ids"
      end

      {
        type: "object",
        properties: properties,
        required: required,
        additionalProperties: false
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
        }
      }
    end
end
