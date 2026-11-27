# frozen_string_literal: true

module Schemas
  module QuestionsFormulars
    QUESTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the question', example: 1 },
        title: { type: :string, nullable: true, description: 'Question text in the current language', example: 'Which infrastructure improvement is most important?' },
        translations: Schemas::Miscellaneous.translations_schema(%w[title]),
        comments_enabled: { type: :boolean, nullable: true, description: 'Whether visitors can comment on the question', example: true },
        show_answers_count: { type: :boolean, nullable: true, description: 'Whether the site shows how many people chose each option. When false, read-only clients get no answer counts.', example: true },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this question belongs to', example: 8 },
        projekt_livestream_id: { type: :integer, nullable: true, description: 'ID of the livestream the question was asked in', example: nil },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who asked the question. Only returned to admin clients.', example: 15 },
        author: { '$ref' => '#/components/schemas/Author' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the question was created', example: '2024-01-10T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the question was last modified', example: '2024-01-15T11:00:00Z' },
        answers_count: { type: :integer, description: 'Number of answers. Omitted for read-only clients when show_answers_count is false.', example: 42 },
        question_options: {
          type: :array,
          description: 'Answer options of the question, in order',
          items: {
            type: :object,
            properties: {
              id: { type: :integer, example: 3 },
              value: { type: :string, nullable: true, description: 'Option text in the current language', example: 'Public Transportation' },
              answers_count: { type: :integer, description: 'Times the option was chosen. Omitted for read-only clients when show_answers_count is false.', example: 17 }
            },
            additionalProperties: false
          }
        },
        projekt_livestream: {
          type: :object,
          properties: {
            id: { type: :integer },
            title: { type: :string, nullable: true },
            url: { type: :string, nullable: true }
          },
          additionalProperties: false
        },
        projekt_phase: { '$ref' => '#/components/schemas/ProjektPhaseReference' },
        projekt: { '$ref' => '#/components/schemas/ProjektReference' }
      },
      required: %w[id created_at updated_at translations comments_enabled show_answers_count],
      additionalProperties: false
    }.freeze

    QUESTION_OPTION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the question option', example: 1 },
        value: { type: :string, nullable: true, description: 'Option text in the current language', example: 'Public Transportation' },
        translations: Schemas::Miscellaneous.translations_schema(%w[value]),
        projekt_question_id: { type: :integer, description: 'ID of the question this option belongs to', example: 5 },
        question: {
          type: :object,
          properties: {
            id: { type: :integer },
            title: { type: :string, nullable: true }
          },
          additionalProperties: false
        },
        answers_count: { type: :integer, description: 'Times the option was chosen. Omitted for read-only clients when the question hides answer counts.', example: 17 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the option was created', example: '2024-01-10T09:15:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the option was last modified', example: '2024-01-10T09:15:00Z' }
      },
      required: %w[id projekt_question_id translations created_at updated_at],
      additionalProperties: false
    }.freeze

    FORMULAR_SCHEMA = {
      type: :object,
      description: 'The form of a FormularPhase. Its heading and texts are the texts of the phase; its fields are listed under /api/formulars/{formular_id}/formular_fields.',
      properties: {
        id: { type: :integer, description: 'Unique identifier for the formular', example: 1 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this formular belongs to', example: 5 },
        formular_fields_count: { type: :integer, description: 'Number of form fields defined in this formular', example: 12 },
        formular_answers_count: { type: :integer, description: 'Number of submissions. The submissions themselves are never returned.', example: 45 },
        settings: {
          type: :object,
          description: 'Settings of the formular phase that govern submissions, as shown in /adm',
          properties: {
            primary_cutoff_date: { type: :string, nullable: true, description: 'Date (YYYY-MM-DD) after which the formular takes no more submissions; empty when unset', example: '2026-12-31' },
            submissions_limit: { type: :string, nullable: true, description: 'How many times one user may submit the formular', example: '1' }
          }
        },
        projekt_phase: {
          type: :object,
          description: 'The projekt phase this formular belongs to',
          properties: {
            id: { type: :integer, example: 5 },
            title: { type: :string, nullable: true, example: 'Feedback Phase' },
            type: { type: :string, example: 'ProjektPhase::FormularPhase' },
            projekt_id: { type: :integer, example: 2 }
          }
        },
        projekt: {
          type: :object,
          description: 'The projekt this formular belongs to',
          properties: {
            id: { type: :integer, example: 2 },
            title: { type: :string, example: 'Community Survey' }
          }
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the formular was created', example: '2024-01-10T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the formular was last modified', example: '2024-01-15T14:30:00Z' }
      },
      required: %w[id projekt_phase_id created_at updated_at],
      additionalProperties: false
    }.freeze

    FORMULAR_FIELD_SCHEMA = {
      type: :object,
      description: 'One field of a formular, as the public form shows it',
      properties: {
        id: { type: :integer, description: 'Unique identifier for the field', example: 31 },
        formular_id: { type: :integer, description: 'ID of the formular the field belongs to', example: 1 },
        key: { type: :string, description: 'Key the answers of this field are stored under', example: 'your_district_31' },
        kind: { type: :string, enum: %w[string textarea email date dropdown image document description], description: 'Input type of the field. description is a text block without an input.', example: 'dropdown' },
        required: { type: :boolean, description: 'Whether the field must be filled in', example: true },
        given_order: { type: :integer, nullable: true, description: 'Position of the field in the form', example: 2 },
        follow_up: { type: :boolean, nullable: true, description: 'Whether the field belongs to the follow-up form sent after a submission', example: false },
        name: { type: :string, nullable: true, description: 'Label of the field in the current language', example: 'Your district' },
        description: { type: :string, nullable: true, description: 'Help text of the field in the current language', example: 'Where do you live?' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name description]),
        options: {
          type: :object,
          description: 'Input options of the field: drop_down_options (comma-separated choices of a dropdown) and validates (length or format rules). Admin clients also receive the confirmation email settings (email_for_confirmation, email_for_confirmation_subject, email_for_confirmation_text).',
          example: { drop_down_options: 'Nord, Süd, Mitte' }
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the field was created', example: '2024-01-10T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the field was last modified', example: '2024-01-15T14:30:00Z' }
      },
      required: %w[id formular_id key kind required name translations options],
      additionalProperties: false
    }.freeze

    def self.all
      {
        Question: QUESTION_SCHEMA,
        QuestionOption: QUESTION_OPTION_SCHEMA,
        Formular: FORMULAR_SCHEMA,
        FormularField: FORMULAR_FIELD_SCHEMA
      }
    end
  end
end
