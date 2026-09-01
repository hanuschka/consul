# frozen_string_literal: true

module Schemas
  module Polls
    VOTATION_TYPE_ATTRIBUTES_SCHEMA = {
      type: :object,
      properties: {
        vote_type: { type: :string, enum: %w[unique multiple multiple_with_weight rating_scale],
description: "Votation type" },
        max_votes: { type: :integer, nullable: true,
description: "Max total votes allowed (for multiple types)" },
        max_votes_per_answer: { type: :integer, nullable: true,
description: "Max votes per single answer (for multiple types)" },
        show_hint_callout: { type: :boolean, nullable: true, description: "Show blue info box in frontend" }
      }
    }.freeze

    POLL_QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: "Unique identifier for the poll question", example: 1 },
        title: { type: :string, description: "The question text in the current locale",
example: "What is your preference?" },
        description: { type: :string, nullable: true, description: "Description text in the current locale" },
        intro: { type: :string, nullable: true,
description: "Introduction text shown above the question in the current locale" },
        multiple: { type: :boolean, nullable: true, description: "Whether multiple answers can be selected",
example: false },
        show_images: { type: :boolean, nullable: true, description: "Display answer options as images" },
        answer_mandatory: { type: :boolean, nullable: true,
description: "Whether answering this question is mandatory" },
        vote_type: { type: :string, nullable: true,
description: "Votation type (unique, multiple, multiple_with_weight, rating_scale)" },
        show_hint_callout: { type: :boolean, nullable: true, description: "Show blue info box in frontend" },
        bundle_question: { type: :boolean, nullable: true,
description: "Whether this is a bundle question (container for nested questions)" },
        given_order: { type: :integer, nullable: true, description: "Display order of the question",
example: 1 },
        randomize_answers: { type: :boolean, nullable: true,
description: "Shuffle the answer options per participant (ignored for rating_scale and map_points)" },
        randomize_position: { type: :boolean, nullable: true,
description: "Shuffle the question position (cleared for bundle, contextualized or branching questions)" },
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
      required: %w[id created_at updated_at]
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
        title: { type: :string, description: "The answer text in the current locale", example: "Option A" },
        description: { type: :string, nullable: true, description: "Description in the current locale" },
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
        total_votes: { type: :integer, description: "Total number of votes for this answer", example: 42 },
        total_votes_percentage: { type: :number, description: "Percentage of total votes", example: 35.5 },
        videos: { type: :array, items: POLL_QUESTION_ANSWER_VIDEO_SCHEMA, description: "External videos" }
      },
      required: %w[id title]
    }.freeze

    POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: "Multilingual content. Provide title, description, and intro for each language.",
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
      description: "Update multilingual content",
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
      description: "Multilingual content. Provide title and description for each language.",
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
      description: "Update multilingual content",
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

    POLL_QUESTION_CREATE_PARAMS = {
      type: :object,
      properties: {
        question: {
          type: :object,
          properties: {
            title: { type: :string, description: "Question title (sets title for the current locale)" },
            description: { type: :string, nullable: true,
description: "Description text (sets for the current locale)" },
            intro: { type: :string, nullable: true,
description: "Introduction text (sets for the current locale)" },
            multiple: { type: :boolean, nullable: true,
description: "Whether multiple answers can be selected" },
            show_images: { type: :boolean, nullable: true, description: "Display answer options as images" },
            answer_mandatory: { type: :boolean, nullable: true,
description: "Whether answering is mandatory" },
            bundle_question: { type: :boolean, nullable: true,
description: "Set to true to create a bundle question (container for nested questions)" },
            given_order: { type: :integer, nullable: true,
description: "Display order (auto-assigned if omitted)" },
            randomize_answers: { type: :boolean, nullable: true,
description: "Shuffle the answer options per participant (ignored for rating_scale and map_points)" },
            randomize_position: { type: :boolean, nullable: true,
description: "Shuffle the question position (cleared for bundle, contextualized or branching questions)" },
            votation_type_attributes: VOTATION_TYPE_ATTRIBUTES_SCHEMA,
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE
          }
        }
      },
      required: ["question"]
    }.freeze

    POLL_QUESTION_UPDATE_PARAMS = {
      type: :object,
      properties: {
        question: {
          type: :object,
          properties: {
            title: { type: :string, nullable: true,
description: "Question title (sets title for the current locale)" },
            description: { type: :string, nullable: true,
description: "Description text (sets for the current locale)" },
            intro: { type: :string, nullable: true,
description: "Introduction text (sets for the current locale)" },
            multiple: { type: :boolean, nullable: true,
description: "Whether multiple answers can be selected" },
            show_images: { type: :boolean, nullable: true, description: "Display answer options as images" },
            answer_mandatory: { type: :boolean, nullable: true,
description: "Whether answering is mandatory" },
            bundle_question: { type: :boolean, nullable: true,
description: "Whether this is a bundle question (container for nested questions)" },
            given_order: { type: :integer, nullable: true, description: "Display order of the question" },
            randomize_answers: { type: :boolean, nullable: true,
description: "Shuffle the answer options per participant (ignored for rating_scale and map_points)" },
            randomize_position: { type: :boolean, nullable: true,
description: "Shuffle the question position (cleared for bundle, contextualized or branching questions)" },
            votation_type_attributes: VOTATION_TYPE_ATTRIBUTES_SCHEMA,
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_UPDATE
          }
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

    POLL_QUESTION_ANSWER_CREATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: {
            title: { type: :string, description: "Answer title (sets title for the current locale)" },
            description: { type: :string, nullable: true,
description: "Answer description (sets for the current locale)" },
            open_answer: { type: :boolean, nullable: true,
description: "Free-text answer (no predefined options)" },
            more_info_link: { type: :string, nullable: true, description: "External link URL for more info" },
            more_info_iframe: { type: :string, nullable: true, description: "Embedded iframe URL" },
            next_question_id: { type: :integer, nullable: true,
description: "ID of next question to show after this answer" },
            terminates_poll: { type: :boolean, nullable: true,
description: "Whether selecting this answer ends the poll" },
            given_order: { type: :integer, nullable: true,
description: "Display order (auto-assigned if omitted)" },
            videos_attributes: POLL_QUESTION_ANSWER_VIDEOS_ATTRIBUTES,
            translations_attributes: POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_CREATE
          }
        }
      },
      required: ["answer"]
    }.freeze

    POLL_QUESTION_ANSWER_UPDATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: {
            title: { type: :string, nullable: true,
description: "Answer title (sets title for the current locale)" },
            description: { type: :string, nullable: true,
description: "Answer description (sets for the current locale)" },
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
            translations_attributes: POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_UPDATE
          }
        }
      }
    }.freeze

    def self.all
      {
        PollQuestion: POLL_QUESTION_SCHEMA,
        PollQuestionAnswer: POLL_QUESTION_ANSWER_SCHEMA
      }
    end
  end
end
