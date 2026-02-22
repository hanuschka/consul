# frozen_string_literal: true

module Schemas
  module Polls
    POLL_QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the poll question', example: 1 },
        title: { type: :string, description: 'The question text in the current locale', example: 'What is your preference?' },
        multiple: { type: :boolean, nullable: true, description: 'Whether multiple answers can be selected', example: false },
        given_order: { type: :integer, nullable: true, description: 'Display order of the question', example: 1 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the question was created', example: '2024-01-10T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the question was last modified', example: '2024-01-15T11:00:00Z' },
        answers: {
          type: :array,
          description: 'Available answer options for this question',
          items: { '$ref' => '#/components/schemas/PollQuestionAnswer' }
        }
      },
      required: %w[id created_at updated_at]
    }.freeze

    POLL_QUESTION_ANSWER_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the answer', example: 1 },
        title: { type: :string, description: 'The answer text in the current locale', example: 'Option A' },
        description: { type: :string, nullable: true, description: 'Optional description for the answer in the current locale', example: 'Additional context for option A' },
        given_order: { type: :integer, nullable: true, description: 'Display order of the answer', example: 1 },
        total_votes: { type: :integer, description: 'Total number of votes for this answer', example: 42 },
        total_votes_percentage: { type: :number, description: 'Percentage of total votes this answer received', example: 35.5 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the answer was created', example: '2024-01-10T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the answer was last modified', example: '2024-01-15T11:00:00Z' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: 'Multilingual content. Provide title for each language.',
      items: {
        type: :object,
        properties: {
          locale: { type: :string, description: 'Language code (e.g., en, de)' },
          title: { type: :string, description: 'Question title in the specified language' }
        }
      }
    }.freeze

    POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_UPDATE = {
      type: :array,
      nullable: true,
      description: 'Update multilingual content',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true, description: 'Translation ID (required for updating existing translations)' },
          locale: { type: :string, description: 'Language code (e.g., en, de)' },
          title: { type: :string, nullable: true, description: 'Question title in the specified language' },
          _destroy: { type: :boolean, nullable: true }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_CREATE = {
      type: :array,
      description: 'Multilingual content. Provide title and description for each language.',
      items: {
        type: :object,
        properties: {
          locale: { type: :string, description: 'Language code (e.g., en, de)' },
          title: { type: :string, description: 'Answer title in the specified language' },
          description: { type: :string, nullable: true, description: 'Answer description in the specified language' }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_UPDATE = {
      type: :array,
      nullable: true,
      description: 'Update multilingual content',
      items: {
        type: :object,
        properties: {
          id: { type: :integer, nullable: true, description: 'Translation ID (required for updating existing translations)' },
          locale: { type: :string, description: 'Language code (e.g., en, de)' },
          title: { type: :string, nullable: true, description: 'Answer title in the specified language' },
          description: { type: :string, nullable: true, description: 'Answer description in the specified language' },
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
            title: { type: :string, description: 'Question title (sets title for the current locale)' },
            multiple: { type: :boolean, nullable: true, description: 'Whether multiple answers can be selected' },
            given_order: { type: :integer, nullable: true, description: 'Display order of the question' },
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_CREATE
          }
        }
      },
      required: ['question']
    }.freeze

    POLL_QUESTION_UPDATE_PARAMS = {
      type: :object,
      properties: {
        question: {
          type: :object,
          properties: {
            title: { type: :string, nullable: true, description: 'Question title (sets title for the current locale)' },
            multiple: { type: :boolean, nullable: true, description: 'Whether multiple answers can be selected' },
            given_order: { type: :integer, nullable: true, description: 'Display order of the question' },
            translations_attributes: POLL_QUESTION_TRANSLATIONS_ATTRIBUTES_UPDATE
          }
        }
      }
    }.freeze

    POLL_QUESTION_ANSWER_CREATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: {
            title: { type: :string, description: 'Answer title (sets title for the current locale)' },
            description: { type: :string, nullable: true, description: 'Answer description (sets description for the current locale)' },
            given_order: { type: :integer, nullable: true, description: 'Display order (auto-assigned if omitted)' },
            translations_attributes: POLL_QUESTION_ANSWER_TRANSLATIONS_ATTRIBUTES_CREATE
          }
        }
      },
      required: ['answer']
    }.freeze

    POLL_QUESTION_ANSWER_UPDATE_PARAMS = {
      type: :object,
      properties: {
        answer: {
          type: :object,
          properties: {
            title: { type: :string, nullable: true, description: 'Answer title (sets title for the current locale)' },
            description: { type: :string, nullable: true, description: 'Answer description (sets description for the current locale)' },
            given_order: { type: :integer, nullable: true, description: 'Display order of the answer' },
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
