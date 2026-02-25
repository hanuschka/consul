# frozen_string_literal: true

module Schemas
  module QuestionsFormulars
    QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the question', example: 1 },
        title: { type: :string, description: 'The question text or title', example: 'Which infrastructure improvement is most important?' },
        description: { type: :string, nullable: true, description: 'Additional context or description for the question', example: 'Help us prioritize improvements' },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this question belongs to', example: 8 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the question was created', example: '2024-01-10T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the question was last modified', example: '2024-01-15T11:00:00Z' },
        question_options: {
          type: :array,
          description: 'Available answer options for this question',
          items: { '$ref' => '#/components/schemas/QuestionOption' }
        }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    QUESTION_OPTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the question option', example: 1 },
        title: { type: :string, description: 'The text of the answer option', example: 'Public Transportation' },
        position: { type: :integer, description: 'Display order of this option among other options', example: 0 },
        question_id: { type: :integer, description: 'ID of the question this option belongs to', example: 5 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the option was created', example: '2024-01-10T09:15:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the option was last modified', example: '2024-01-10T09:15:00Z' }
      },
      required: %w[id title position question_id created_at updated_at]
    }.freeze

    FORMULAR_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the form', example: 1 },
        title: { type: :string, description: 'The title or name of the form', example: 'Community Feedback Survey' },
        description: { type: :string, nullable: true, description: 'Description of the form purpose and content', example: 'Please provide your feedback on community initiatives' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this form belongs to', example: 12 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the form was created', example: '2024-01-08T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the form was last modified', example: '2024-01-12T14:20:00Z' }
      },
      required: %w[id title projekt_phase_id created_at updated_at]
    }.freeze

    TEXT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the text block', example: 1 },
        title: { type: :string, nullable: true, description: 'Optional title for the text content', example: 'Phase Information' },
        body: { type: :string, nullable: true, description: 'The main text content (may contain HTML)', example: 'This phase focuses on gathering community input...' },
        locale: { type: :string, description: 'Language code for this text (e.g., en, de, es)', example: 'en' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this text belongs to', example: 7 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the text was created', example: '2024-01-02T08:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the text was last modified', example: '2024-01-12T15:00:00Z' }
      },
      required: %w[id locale projekt_phase_id created_at updated_at]
    }.freeze

    def self.all
      {
        Question: QUESTION_SCHEMA,
        QuestionOption: QUESTION_OPTION_SCHEMA,
        Formular: FORMULAR_SCHEMA,
        Text: TEXT_SCHEMA
      }
    end
  end
end
