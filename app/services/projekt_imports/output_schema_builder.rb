module ProjektImports::OutputSchemaBuilder
  def self.build(refs)
    phase_types = refs["phase_types"] || []

    {
      type: "object",
      properties: {
        title: {
          type: "string",
          description: "Project title derived from document"
        },
        subtitle: {
          type: %w[string null],
          description: "Project subtitle or tagline"
        },
        content_blocks: {
          type: "array",
          items: content_block_item_schema
        },
        projekt_start_date: {
          type: %w[string null],
          description: "ISO 8601 date (YYYY-MM-DD)"
        },
        projekt_end_date: {
          type: %w[string null],
          description: "ISO 8601 date (YYYY-MM-DD)"
        },
        categories: categories_schema(refs),
        sdg_codes: sdg_codes_schema(refs),
        phases: {
          type: "array",
          items: phase_item_schema(phase_types)
        },
        projekt_settings: build_projekt_settings_schema(refs),
        projekt_phase_settings: build_phase_settings_schema(refs),
        image_prompt: {
          type: %w[string null],
          description: "English prompt for AI image generation"
        },
        needs_clarification: {
          type: "boolean",
          description: "Set to true in most cases. Only false if document is exceptionally detailed with zero ambiguity."
        },
        clarification_questions: {
          type: "array",
          items: { type: "string" },
          minItems: 2,
          description: "Specific questions for the user. MUST include at least 2-3 questions."
        }
      },
      required: %w[
        title subtitle content_blocks projekt_start_date
        projekt_end_date categories sdg_codes phases
        projekt_settings projekt_phase_settings image_prompt
        needs_clarification clarification_questions
      ],
      additionalProperties: false
    }
  end

  def self.categories_schema(refs)
    tags = Array(refs["tags"]).compact.uniq
    items = { type: "string" }
    items[:enum] = tags if tags.present?

    { type: "array", items: items }
  end

  def self.sdg_codes_schema(refs)
    codes = Array(refs["sdg_goals"]).map { |goal| goal["code"].to_s }.compact_blank.uniq
    items = { type: "string" }
    items[:enum] = codes if codes.present?

    { type: "array", items: items }
  end

  def self.content_block_item_schema
    {
      type: "object",
      properties: {
        template_id: { type: "integer", description: "ID of the chosen content block template" },
        content_data: { type: "string", description: "The actual text content to fill into the template. Use markdown-like formatting." }
      },
      required: %w[template_id content_data],
      additionalProperties: false
    }
  end

  def self.phase_item_schema(phase_types)
    {
      type: "object",
      properties: {
        type: { type: "string", enum: phase_types },
        name: {
          type: %w[string null],
          description: "Display name of the phase tab, in the requested output " \
                       "language. Use the default name listed for this phase type " \
                       "unless the document states a different one. Never use the " \
                       "type identifier or an anglicised form of it such as " \
                       "\"Voting Phase\"."
        },
        start_date: { type: %w[string null], description: "YYYY-MM-DD" },
        end_date: { type: %w[string null], description: "YYYY-MM-DD" },
        description: {
          type: %w[string null],
          description: "Phase description, in the requested output language"
        },
        cta_button_name: {
          type: %w[string null],
          description: "CTA button label, in the requested output language"
        },
        intro_content: {
          type: %w[string null],
          description: "Short markdown text rendered directly ABOVE this phase's " \
                       "content in the projekt footer. Two or three sentences at " \
                       "most, specific to this phase. Null when the document " \
                       "offers nothing to say."
        },
        outro_content: {
          type: %w[string null],
          description: "Short markdown text rendered directly BELOW this phase's " \
                       "content in the projekt footer, e.g. what happens with the " \
                       "results or where to ask questions. Null when the document " \
                       "offers nothing to say."
        },
        user_status: {
          type: %w[string null],
          enum: ["guest", "registered", "verified", nil],
          description: "Required user verification level"
        },
        poll_questions: { type: "array", items: poll_question_schema },
        events: { type: "array", items: event_schema },
        milestones: { type: "array", items: milestone_schema },
        arguments: { type: "array", items: argument_schema },
        notifications: { type: "array", items: notification_schema },
        progress_bars: { type: "array", items: progress_bar_schema },
        budget: budget_schema,
        iframe: iframe_schema,
        livestreams: { type: "array", items: livestream_schema },
        point_of_interest_categories: { type: "array", items: poi_category_schema },
        projekt_labels: { type: "array", items: projekt_label_schema },
        sentiments: { type: "array", items: sentiment_schema }
      },
      required: %w[
        type name start_date end_date description cta_button_name intro_content
        outro_content user_status poll_questions events milestones arguments
        notifications progress_bars budget iframe livestreams
        point_of_interest_categories projekt_labels sentiments
      ],
      additionalProperties: false
    }
  end

  def self.poll_question_schema
    {
      type: "object",
      properties: {
        title: { type: "string", minLength: 4 },
        description: { type: %w[string null] },
        vote_type: { type: %w[string null], enum: ["unique", "multiple", "rating_scale", nil] },
        min_rating_scale_label: {
          type: %w[string null],
          description: "Caption for the low end of a rating_scale question. Null otherwise."
        },
        max_rating_scale_label: {
          type: %w[string null],
          description: "Caption for the high end of a rating_scale question. Null otherwise."
        },
        answers: {
          type: "array",
          minItems: 2,
          description: "Selectable options. For a rating_scale question these are the scale points.",
          items: {
            type: "object",
            properties: {
              title: { type: "string", minLength: 1 },
              description: { type: %w[string null], description: "Optional explanatory text" }
            },
            required: %w[title description],
            additionalProperties: false
          }
        }
      },
      required: %w[
        title description vote_type min_rating_scale_label
        max_rating_scale_label answers
      ],
      additionalProperties: false
    }
  end

  def self.event_schema
    {
      type: "object",
      properties: {
        title: { type: "string" },
        description: { type: %w[string null] },
        datetime: { type: %w[string null], description: "YYYY-MM-DDTHH:MM" },
        end_datetime: { type: %w[string null] },
        location: { type: %w[string null] },
        weblink: { type: %w[string null] }
      },
      required: %w[title description datetime end_datetime location weblink],
      additionalProperties: false
    }
  end

  def self.milestone_schema
    {
      type: "object",
      properties: {
        title: { type: "string" },
        description: { type: %w[string null] },
        publication_date: { type: %w[string null], description: "YYYY-MM-DD" }
      },
      required: %w[title description publication_date],
      additionalProperties: false
    }
  end

  def self.argument_schema
    {
      type: "object",
      properties: {
        name: { type: "string", description: "Person or organization name" },
        position: { type: "string", description: "Role or title" },
        note: { type: "string", description: "Argument text" },
        pro: { type: "boolean", description: "true=pro, false=con" }
      },
      required: %w[name position note pro],
      additionalProperties: false
    }
  end

  def self.notification_schema
    {
      type: "object",
      properties: {
        title: { type: "string" },
        body: { type: "string" }
      },
      required: %w[title body],
      additionalProperties: false
    }
  end

  def self.progress_bar_schema
    {
      type: "object",
      properties: {
        title: { type: "string", description: "Progress bar label" },
        kind: { type: "string", enum: %w[primary secondary] },
        percentage: { type: "integer", description: "0-100" }
      },
      required: %w[title kind percentage],
      additionalProperties: false
    }
  end

  def self.budget_schema
    {
      type: %w[object null],
      description: "Budget settings for BudgetPhase. Null for non-budget phases.",
      properties: {
        currency_symbol: { type: "string", enum: %w[€ $ £ ¥] },
        voting_style: { type: "string", enum: %w[knapsack approval distributed] },
        total_amount: { type: %w[integer null], description: "Total budget amount" },
        hide_money: { type: "boolean" },
        phases: {
          type: %w[array null],
          description: "Budget workflow phases with dates. Null if no dates mentioned.",
          items: {
            type: "object",
            properties: {
              kind: { type: "string", enum: %w[informing accepting reviewing selecting valuating publishing_prices balloting reviewing_ballots finished] },
              enabled: { type: "boolean" },
              starts_at: { type: %w[string null], description: "YYYY-MM-DD" },
              ends_at: { type: %w[string null], description: "YYYY-MM-DD" }
            },
            required: %w[kind enabled starts_at ends_at],
            additionalProperties: false
          }
        }
      },
      required: %w[currency_symbol voting_style total_amount hide_money phases],
      additionalProperties: false
    }
  end

  def self.iframe_schema
    {
      type: %w[object null],
      description: "Iframe settings for IframePhase. Null for non-iframe phases.",
      properties: {
        url: { type: "string", description: "External URL to embed" },
        width: { type: %w[string null], description: "Width (e.g. '100%' or '800')" },
        height: { type: %w[string null], description: "Height (e.g. '600')" }
      },
      required: %w[url width height],
      additionalProperties: false
    }
  end

  def self.livestream_schema
    {
      type: "object",
      properties: {
        url: { type: "string", description: "Video URL (YouTube or Vimeo)" },
        title: { type: %w[string null] },
        description: { type: %w[string null] },
        starts_at: { type: %w[string null], description: "YYYY-MM-DDTHH:MM" }
      },
      required: %w[url title description starts_at],
      additionalProperties: false
    }
  end

  def self.projekt_label_schema
    {
      type: "object",
      description: "One entry of the phase's single multi-select label group. " \
                   "Only ProposalPhase and BudgetPhase support labels.",
      properties: {
        name: { type: "string", description: "Label text shown to citizens" },
        icon: {
          type: %w[string null],
          description: "Font Awesome icon name without the fa- prefix (e.g. tree). Null for no icon."
        }
      },
      required: %w[name icon],
      additionalProperties: false
    }
  end

  def self.sentiment_schema
    {
      type: "object",
      description: "One entry of the phase's single single-select sentiment group. " \
                   "Only ProposalPhase and BudgetPhase support sentiments.",
      properties: {
        name: { type: "string", description: "Sentiment text shown to citizens" },
        color: { type: %w[string null], description: "Hex color code (e.g. #3366CC)" }
      },
      required: %w[name color],
      additionalProperties: false
    }
  end

  def self.poi_category_schema
    {
      type: "object",
      properties: {
        name: { type: "string", description: "Category name" },
        color: { type: "string", description: "Hex color code (e.g. #FF5733)" },
        icon: { type: "string", description: "Font Awesome icon name (e.g. fa-tree)" }
      },
      required: %w[name color icon],
      additionalProperties: false
    }
  end

  def self.build_projekt_settings_schema(refs)
    settings = refs["projekt_settings"] || {}
    properties = {}

    settings.each_key do |key|
      properties[key] = { type: %w[string null] }
    end

    {
      type: "object",
      properties: properties,
      required: properties.keys,
      additionalProperties: false
    }
  end

  def self.build_phase_settings_schema(refs)
    phase_settings = refs["projekt_phase_settings"] || {}
    properties = {}

    phase_settings.each do |phase_type, settings|
      phase_properties = {}

      settings.each_key do |key|
        phase_properties[key] = { type: %w[string null] }
      end

      properties[phase_type] = {
        type: "object",
        properties: phase_properties,
        required: phase_properties.keys,
        additionalProperties: false
      }
    end

    {
      type: "object",
      properties: properties,
      required: properties.keys,
      additionalProperties: false
    }
  end
end
