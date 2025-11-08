# frozen_string_literal: true

module Schemas
  module Ideas
    IDEA_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea', example: 1 },
        title: { type: :string, description: 'The title or headline of the idea', example: 'Improve Public Parks' },
        description: { type: :string, nullable: true, description: 'Detailed description of the idea and its benefits', example: 'Upgrade existing parks with new equipment and maintenance' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the idea', example: 42 },
        admin_accepted_at: { type: :string, format: :date_time, nullable: true, description: 'Timestamp when an admin approved the idea. Null if pending or rejected.', example: '2024-01-15T10:30:00Z' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the idea was created', example: '2024-01-10T08:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the idea was last modified', example: '2024-01-15T14:22:00Z' },
        category_id: { type: :integer, nullable: true, description: 'ID of the idea category. Null if uncategorized.', example: 5 },
        category: {
          type: :object,
          nullable: true,
          description: 'The category object if populated',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, description: 'Category name' }
          }
        },
        officer_id: { type: :integer, nullable: true, description: 'ID of the assigned idea officer/manager', example: 10 },
        officer: {
          type: :object,
          nullable: true,
          description: 'The assigned idea officer information if populated',
          properties: {
            id: { type: :integer, description: 'Officer ID' },
            name: { type: :string, description: 'Officer name' }
          }
        }
      },
      required: %w[id created_at updated_at]
    }.freeze

    IDEA_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea category', example: 1 },
        name: { type: :string, description: 'The name of the category', example: 'Infrastructure' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    IDEA_OFFICER_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the idea officer', example: 1 },
        name: { type: :string, description: 'The name of the idea officer or manager', example: 'John Smith' },
        email: { type: :string, nullable: true, description: 'The email address of the officer', example: 'john.smith@example.com' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the officer record was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the officer record was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name created_at updated_at]
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
