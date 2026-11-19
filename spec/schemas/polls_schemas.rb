# frozen_string_literal: true

module Schemas
  module Polls
    VOTE_TYPES = %w[unique multiple multiple_with_weight rating_scale map_points].freeze

    RATING_LABEL_TRANSLATIONS = Schemas::Miscellaneous.translations_schema(
      %w[min_rating_scale_label max_rating_scale_label]
    )

    VOTATION_TYPE_ATTRIBUTES_SCHEMA = {
      type: :object,
      properties: {
        vote_type: { type: :string, enum: VOTE_TYPES, description: "Votation type" },
        max_votes: { type: :integer, nullable: true,
description: "Max total votes allowed (multiple types); for map_points the number of points a participant may set" },
        max_votes_per_answer: { type: :integer, nullable: true,
description: "Max votes per single answer (for multiple types)" },
        show_hint_callout: { type: :boolean, nullable: true, description: "Show blue info box in frontend" },
        min_rating_scale_label: { type: :string, nullable: true,
description: "Label of the lowest rating (rating_scale), current language" },
        max_rating_scale_label: { type: :string, nullable: true,
description: "Label of the highest rating (rating_scale), current language" },
        translations: RATING_LABEL_TRANSLATIONS
      }
    }.freeze

    VOTATION_TYPE_SCHEMA = {
      type: :object,
      nullable: true,
      description: "How the question is answered",
      properties: {
        vote_type: { type: :string, enum: VOTE_TYPES, description: "Votation type" },
        max_votes: { type: :integer, nullable: true,
description: "Max total votes (multiple types); number of points a participant may set (map_points)" },
        max_votes_per_answer: { type: :integer, nullable: true, description: "Max votes per single answer" },
        show_hint_callout: { type: :boolean, nullable: true, description: "Show blue info box in frontend" },
        min_rating_scale_label: { type: :string, nullable: true, description: "Label of the lowest rating" },
        max_rating_scale_label: { type: :string, nullable: true, description: "Label of the highest rating" },
        translations: RATING_LABEL_TRANSLATIONS
      },
      additionalProperties: false
    }.freeze

    POLL_QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: "Unique identifier for the poll question", example: 1 },
        poll_id: { type: :integer, description: "ID of the poll", example: 3 },
        title: { type: :string, description: "The question text in the current locale",
example: "What is your preference?" },
        description: { type: :string, nullable: true, description: "Description text in the current locale" },
        intro: { type: :string, nullable: true,
description: "Introduction text shown above the question in the current locale" },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description intro]),
        multiple: { type: :boolean, nullable: true, description: "Whether multiple answers can be selected",
example: false },
        show_images: { type: :boolean, nullable: true, description: "Display answer options as images" },
        answer_mandatory: { type: :boolean, nullable: true,
description: "Whether answering this question is mandatory" },
        vote_type: { type: :string, nullable: true, enum: [*VOTE_TYPES, nil],
description: "Votation type (same as votation_type.vote_type)" },
        show_hint_callout: { type: :boolean, nullable: true, description: "Show blue info box in frontend" },
        votation_type: VOTATION_TYPE_SCHEMA,
        bundle_question: { type: :boolean, nullable: true,
description: "Whether this is a bundle question (container for nested questions)" },
        parent_question_id: { type: :integer, nullable: true,
description: "Bundle question this question is nested in" },
        nested_question_ids: { type: :array, items: { type: :integer },
description: "Questions nested in this bundle question, in display order" },
        contextualize_by_poll_question_id: { type: :integer, nullable: true,
description: "Question whose answers this question is repeated for (context question). The poll then holds one generated copy per answer." },
        context_id: { type: :integer, nullable: true,
description: "On a generated copy: the answer of the context question it was generated for. Read-only." },
        contexted_clone_of_poll_question_id: { type: :integer, nullable: true,
description: "On a generated copy: the question it was generated from. Read-only." },
        given_order: { type: :integer, nullable: true, description: "Display order of the question",
example: 1 },
        randomize_answers: { type: :boolean, nullable: true,
description: "Shuffle the answer options per participant (ignored for rating_scale and map_points)" },
        randomize_position: { type: :boolean, nullable: true,
description: "Shuffle the question position (cleared for bundle, contextualized or branching questions)" },
        map_location: { "$ref" => "#/components/schemas/MapLocation" },
        created_at: { type: :string, format: :date_time,
description: "Timestamp when the question was created", example: "2024-01-10T09:00:00Z" },
        updated_at: { type: :string, format: :date_time,
description: "Timestamp when the question was last modified", example: "2024-01-15T11:00:00Z" },
        answers: {
          type: :array,
          description: "Available answer options for this question",
          items: { "$ref" => "#/components/schemas/PollQuestionAnswer" }
        }
      },
      required: %w[id poll_id translations votation_type nested_question_ids created_at updated_at],
      additionalProperties: false
    }.freeze

    POLL_QUESTION_ANSWER_VIDEO_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: "Video ID" },
        title: { type: :string, description: "Video title" },
        url: { type: :string, description: "YouTube or Vimeo URL" }
      }
    }.freeze

    POLL_QUESTION_ANSWER_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: "Unique identifier for the answer", example: 1 },
        question_id: { type: :integer, description: "ID of the question", example: 7 },
        title: { type: :string, description: "The answer text in the current locale", example: "Option A" },
        description: { type: :string, nullable: true, description: "Description in the current locale" },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description]),
        open_answer: { type: :boolean, nullable: true,
description: "Free-text answer (no predefined options)" },
        more_info_link: { type: :string, nullable: true, description: "External link URL for more info" },
        more_info_iframe: { type: :string, nullable: true, description: "Embedded iframe URL" },
        next_question_id: { type: :integer, nullable: true,
description: "ID of the next question to show after this answer" },
        terminates_poll: { type: :boolean, nullable: true,
description: "Whether selecting this answer ends the poll" },
        given_order: { type: :integer, nullable: true, description: "Display order of the answer",
example: 1 },
        total_votes: { type: :integer,
description: "Total votes for this answer. Always returned to admin clients; to read-only clients only once the poll's results are public and the poll is live.", example: 42 },
        total_votes_percentage: { type: :number,
description: "Share of the question's votes (0-100). Returned together with total_votes.", example: 35.5 },
        images: { type: :array, items: { "$ref" => "#/components/schemas/ImageResponse" },
description: "Gallery images of the answer" },
        documents: { type: :array, items: { "$ref" => "#/components/schemas/Document" },
description: "Documents attached to the answer" },
        videos: { type: :array, items: POLL_QUESTION_ANSWER_VIDEO_SCHEMA, description: "External videos" }
      },
      required: %w[id title translations images documents],
      additionalProperties: false
    }.freeze

    POLL_RESULTS_ANSWER_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: "Answer ID", example: 11 },
        title: { type: :string, description: "Answer text in the current locale", example: "Option A" },
        open_answer: { type: :boolean, description: "Free-text answer; counts the non-empty texts, never returns them" },
        total_votes: { type: :integer, description: "Votes for the answer: weights of online votes plus booth results", example: 42 },
        percentage: { type: :number, description: "Share of the question's votes (0-100)", example: 35.5 },
        voters_count: { type: :integer, description: "Participants who chose the answer online", example: 40 },
        weights: {
          type: :array,
          description: "Only for multiple_with_weight and rating_scale questions: how many participants gave each weight or rating",
          items: {
            type: :object,
            properties: {
              weight: { type: :integer, example: 3 },
              count: { type: :integer, example: 12 }
            }
          }
        }
      },
      required: %w[id total_votes percentage voters_count],
      additionalProperties: false
    }.freeze

    POLL_RESULTS_QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 7 },
        title: { type: :string, example: "Which square should be redesigned first?" },
        vote_type: { type: :string, nullable: true, enum: [*VOTE_TYPES, nil] },
        max_votes: { type: :integer, nullable: true },
        total_votes: { type: :integer, description: "Sum of the answers' votes", example: 120 },
        answers: { type: :array, items: { "$ref" => "#/components/schemas/PollResultsAnswer" } },
        nested_questions: { type: :array, items: { "$ref" => "#/components/schemas/PollResultsQuestion" } },
        map_points: {
          type: :object,
          description: "Only for map_points questions: every point set by participants as a GeoJSON FeatureCollection, anonymous (feature properties carry only the point id)"
        }
      },
      required: %w[id total_votes answers nested_questions],
      additionalProperties: false
    }.freeze

    POLL_RESULTS_SCHEMA = {
      type: :object,
      description: "Aggregated results of a poll. Single votes, open answer texts and participants are never returned.",
      properties: {
        poll_id: { type: :integer, example: 3 },
        live: { type: :boolean, description: "False while the poll is in test mode", example: true },
        voters_count: { type: :integer, description: "Participants who took part", example: 120 },
        questions: { type: :array, items: { "$ref" => "#/components/schemas/PollResultsQuestion" } }
      },
      required: %w[poll_id live voters_count questions],
      additionalProperties: false
    }.freeze

    POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: "Older per-language format. Prefer translations.",
      items: {
        type: :object,
        properties: {
          locale: { type: :string, description: "Language code (e.g., en, de)" },
          title: { type: :string, description: "Question title in the specified language" },
          description: { type: :string, nullable: true,
description: "Question description in the specified language" },
          intro: { type: :string, nullable: true, description: "Introduction text in the specified language" }
        }
      }
    }.freeze

    POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_UPDATE = {
      type: :array,
      nullable: true,
      description: "Older per-language format. Prefer translations.",
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true,
description: "Translation ID (required for updating existing translations)" },
          locale: { type: :string, description: "Language code (e.g., en, de)" },
          title: { type: :string, nullable: true, description: "Question title in the specified language" },
          description: { type: :string, nullable: true,
description: "Question description in the specified language" },
          intro: { type: :string, nullable: true,
description: "Introduction text in the specified language" },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: "Older per-language format. Prefer translations.",
      items: {
        type: :object,
        properties: {
          locale: { type: :string, description: "Language code (e.g., en, de)" },
          title: { type: :string, description: "Answer title in the specified language" },
          description: { type: :string, nullable: true,
description: "Answer description in the specified language" }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_UPDATE = {
      type: :array,
      nullable: true,
      description: "Older per-language format. Prefer translations.",
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true,
description: "Translation ID (required for updating existing translations)" },
          locale: { type: :string, description: "Language code (e.g., en, de)" },
          title: { type: :string, nullable: true, description: "Answer title in the specified language" },
          description: { type: :string, nullable: true,
description: "Answer description in the specified language" },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    POLL_QUESTION_WRITE_PROPERTIES = {
      title: { type: :string, nullable: true, description: "Question title (sets title for the current locale)" },
      description: { type: :string, nullable: true,
description: "Description text (sets for the current locale)" },
      intro: { type: :string, nullable: true,
description: "Introduction text (sets for the current locale)" },
      translations: Schemas::Miscellaneous.translations_schema(%w[title description intro]),
      multiple: { type: :boolean, nullable: true,
description: "Whether multiple answers can be selected" },
      show_images: { type: :boolean, nullable: true, description: "Display answer options as images" },
      answer_mandatory: { type: :boolean, nullable: true,
description: "Whether answering is mandatory" },
      bundle_question: { type: :boolean, nullable: true,
description: "Set to true for a bundle question (container for nested questions)" },
      parent_question_id: { type: :integer, nullable: true,
description: "Bundle question of the same poll to nest this question in" },
      contextualize_by_poll_question_id: { type: :integer, nullable: true,
description: "Question of the same poll whose answers this question is repeated for. The generated copies are rebuilt after each write, unless the poll already has votes." },
      given_order: { type: :integer, nullable: true,
description: "Display order (auto-assigned on create if omitted)" },
      randomize_answers: { type: :boolean, nullable: true,
description: "Shuffle the answer options per participant (ignored for rating_scale and map_points)" },
      randomize_position: { type: :boolean, nullable: true,
description: "Shuffle the question position (cleared for bundle, contextualized or branching questions)" },
      votation_type_attributes: VOTATION_TYPE_ATTRIBUTES_SCHEMA,
      map_location_attributes: { "$ref" => "#/components/schemas/MapLocationWriteParams" }
    }.freeze

    POLL_QUESTION_CREATE_PARAMS = {
      type: :object,
      properties: {
        question: {
          type: :object,
          properties: POLL_QUESTION_WRITE_PROPERTIES.merge(
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE
          )
        }
      },
      required: ["question"]
    }.freeze

    POLL_QUESTION_UPDATE_PARAMS = {
      type: :object,
      properties: {
        question: {
          type: :object,
          properties: POLL_QUESTION_WRITE_PROPERTIES.merge(
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_UPDATE
          )
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_VIDEOS_ATTRIBUTES = {
      type: :array,
      description: "External videos (YouTube/Vimeo)",
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true, description: "Video ID (required for update/delete)" },
          title: { type: :string, description: "Video title" },
          url: { type: :string, description: "YouTube or Vimeo URL" },
          _destroy: { type: :boolean, nullable: true, description: "Set true to remove video" }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_IMAGES_ATTRIBUTES = {
      type: :array,
      description: "Gallery images. New images carry a base64 attachment; send the id to change or remove an existing one.",
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true, description: "Image ID (required for update/delete)" },
          title: { type: :string, nullable: true, description: "Image title or alt text" },
          attachment: { type: :string, description: "Base64-encoded image file, bare or as a data URI" },
          credits: { type: :string, nullable: true, description: "Image attribution" },
          ai_generated: { type: :boolean, nullable: true, description: "Whether the image was made or edited with AI" },
          _destroy: { type: :boolean, nullable: true, description: "Set true to remove the image" }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_DOCUMENTS_ATTRIBUTES = {
      type: :array,
      description: "Documents. New documents carry a base64 attachment; send the id to remove an existing one.",
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true, description: "Document ID (required for delete)" },
          title: { type: :string, description: "Document title; also used for the file name" },
          attachment: { type: :string, description: "Base64-encoded file, bare or as a data URI" },
          _destroy: { type: :boolean, nullable: true, description: "Set true to remove the document" }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_WRITE_PROPERTIES = {
      title: { type: :string, nullable: true,
description: "Answer title (sets title for the current locale)" },
      description: { type: :string, nullable: true,
description: "Answer description (sets for the current locale)" },
      translations: Schemas::Miscellaneous.translations_schema(%w[title description]),
      open_answer: { type: :boolean, nullable: true,
description: "Free-text answer (no predefined options)" },
      more_info_link: { type: :string, nullable: true, description: "External link URL for more info" },
      more_info_iframe: { type: :string, nullable: true, description: "Embedded iframe URL" },
      next_question_id: { type: :integer, nullable: true,
description: "ID of next question to show after this answer" },
      terminates_poll: { type: :boolean, nullable: true,
description: "Whether selecting this answer ends the poll" },
      given_order: { type: :integer, nullable: true, description: "Display order of the answer" },
      videos_attributes: POLL_QUESTION_ANSWER_VIDEOS_ATTRIBUTES,
      images_attributes: POLL_QUESTION_ANSWER_IMAGES_ATTRIBUTES,
      documents_attributes: POLL_QUESTION_ANSWER_DOCUMENTS_ATTRIBUTES
    }.freeze

    POLL_QUESTION_ANSWER_CREATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: POLL_QUESTION_ANSWER_WRITE_PROPERTIES.merge(
            translations_attributes: POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_CREATE
          )
        }
      },
      required: ["answer"]
    }.freeze

    POLL_QUESTION_ANSWER_UPDATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: POLL_QUESTION_ANSWER_WRITE_PROPERTIES.merge(
            translations_attributes: POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_UPDATE
          )
        }
      }
    }.freeze

    POLL_WRITE_PROPERTIES = {
      name: { type: :string, nullable: true, description: 'Display name of the poll (current language)' },
      summary: { type: :string, nullable: true, description: 'Short summary of the poll topic (current language)' },
      description: { type: :string, nullable: true, description: 'Detailed description of what is being voted on (current language)' },
      closing_note: { type: :string, nullable: true, description: 'Text shown after a participant finished the poll (current language)' },
      translations: Schemas::Miscellaneous.translations_schema(%w[name summary description closing_note]),
      starts_at: { type: :string, format: :date_time, nullable: true, description: 'When voting begins (ISO 8601 format)' },
      ends_at: { type: :string, format: :date_time, nullable: true, description: 'When voting ends (ISO 8601 format)' },
      geozone_restricted: { type: :boolean, nullable: true, description: 'Whether voting is restricted to specific geozones' },
      published: { type: :boolean, nullable: true, description: 'Stored publication flag' },
      show_summary_instead_of_questions: { type: :boolean, nullable: true, description: 'Show the summary instead of the question list on the poll card' },
      budget_id: { type: :integer, nullable: true, description: 'Associated budget ID if this is a budget voting poll' },
      geozone_ids: { type: :array, items: { type: :integer }, description: 'IDs of geozones where voting is allowed (if geozone_restricted is true)' },
      image_attributes: { '$ref' => '#/components/schemas/ImageAttributesApi' }
    }.freeze

    def self.all
      {
        PollQuestion: POLL_QUESTION_SCHEMA,
        PollQuestionAnswer: POLL_QUESTION_ANSWER_SCHEMA,
        PollResults: POLL_RESULTS_SCHEMA,
        PollResultsQuestion: POLL_RESULTS_QUESTION_SCHEMA,
        PollResultsAnswer: POLL_RESULTS_ANSWER_SCHEMA
      }
    end
  end
end
