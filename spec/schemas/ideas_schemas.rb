# frozen_string_literal: true

module Schemas
  module Ideas
    IDEA_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea', example: 1 },
        title: { type: :string, nullable: true, description: 'Title in the current language', example: 'Improve Public Parks' },
        description: { type: :string, nullable: true, description: 'Description in the current language', example: 'Upgrade existing parks with new equipment and maintenance' },
        official_answer: { type: :string, nullable: true, description: 'Official answer of the administration in the current language. Not shown on the public site; only returned to admin clients.', example: '<p>Wir prüfen den Vorschlag.</p>' },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description official_answer]).merge(
          description: 'Texts per language, keyed by locale. official_answer is only included for admin clients.'
        ),
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the idea. Only returned to admin clients.', example: 42 },
        author: { '$ref' => '#/components/schemas/Author' },
        on_behalf_of: { type: :string, nullable: true, description: 'Organisation the idea was submitted on behalf of; shown on the site in place of the author name', example: nil },
        admin_accepted_at: { type: :string, format: :date_time, nullable: true, description: 'When staff accepted the idea; starts its timeframe. Null while pending.', example: '2024-01-15T10:30:00Z' },
        status: { type: :string, enum: %w[active archived pending], description: 'pending until accepted, active within its timeframe, archived afterwards', example: 'active' },
        timeframe: { type: :integer, description: 'Days the idea collects supports after acceptance', example: 50 },
        votes_needed_for_success: { type: :integer, description: 'Supports needed for the idea to succeed', example: 100 },
        remaining_days: { type: :integer, nullable: true, description: 'Days left in the timeframe; null while pending', example: 12 },
        cached_votes_up: { type: :integer, description: 'Number of supports', example: 34 },
        comments_count: { type: :integer, description: 'Number of comments', example: 3 },
        video_url: { type: :string, nullable: true, description: 'Video explaining the idea', example: nil },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the idea was created', example: '2024-01-10T08:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the idea was last modified', example: '2024-01-15T14:22:00Z' },
        idea_category_id: { type: :integer, nullable: true, description: 'ID of the idea category. Null if uncategorized.', example: 5 },
        idea_officer_id: { type: :integer, nullable: true, description: 'ID of the assigned idea officer', example: 10 },
        category: {
          type: :object,
          description: 'The category of the idea',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, nullable: true, description: 'Category name' },
            color: { type: :string, nullable: true, description: 'Category colour' },
            icon: { type: :string, nullable: true, description: 'Category icon' }
          },
          additionalProperties: false
        },
        map_location: { '$ref' => '#/components/schemas/MapLocation' },
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        documents: { type: :array, items: { '$ref' => '#/components/schemas/Document' } }
      },
      required: %w[id created_at updated_at translations status map_location],
      additionalProperties: false
    }.freeze

    IDEA_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea category', example: 1 },
        name: { type: :string, nullable: true, description: 'Name in the current language', example: 'Infrastructure' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name]),
        color: { type: :string, nullable: true, description: 'Colour of the category on maps and cards (hex code or colour name)', example: '#2e7d32' },
        icon: { type: :string, nullable: true, description: 'Font Awesome icon name', example: 'tree' },
        given_order: { type: :integer, nullable: true, description: 'Position of the category in lists', example: 1 },
        idea_officer_id: { type: :integer, nullable: true, description: 'ID of the officer new ideas in this category are assigned to', example: 3 },
        ideas_count: { type: :integer, description: 'Number of accepted ideas in the category', example: 12 },
        default_idea_officer: {
          type: :object,
          nullable: true,
          description: 'Officer new ideas in this category are assigned to. Staff email addresses are never returned.',
          properties: {
            id: { type: :integer, description: 'Officer ID' },
            name: { type: :string, description: 'Officer name. Only returned to admin clients.' }
          }
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name created_at updated_at translations ideas_count],
      additionalProperties: false
    }.freeze

    IDEA_OFFICER_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea officer', example: 1 },
        user_id: { type: :integer, description: 'ID of the officer user account. Only returned to admin clients.', example: 7 },
        name: { type: :string, description: 'The name of the idea officer or manager. Only returned to admin clients. Staff email addresses are never returned.', example: 'John Smith' },
        ideas_count: { type: :integer, description: 'Number of ideas assigned to the officer', example: 4 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the officer record was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the officer record was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id ideas_count created_at updated_at]
    }.freeze

    def self.all
      {
        Idea: IDEA_SCHEMA,
        IdeaCategory: IDEA_CATEGORY_SCHEMA,
        IdeaOfficer: IDEA_OFFICER_SCHEMA
      }
    end
  end
end
