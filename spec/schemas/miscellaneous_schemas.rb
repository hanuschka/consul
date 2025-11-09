# frozen_string_literal: true

module Schemas
  module Miscellaneous
    ARGUMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the argument', example: 1 },
        title: { type: :string, description: 'The title or summary of the argument', example: 'Environmental Benefits of the Project' },
        description: { type: :string, nullable: true, description: 'Detailed argument text and supporting points', example: 'This project will reduce CO2 emissions by 20% annually' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the argument', example: 25 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this argument belongs to', example: 18 },
        position: { type: :integer, nullable: true, description: 'Display order among other arguments', example: 0 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the argument was created', example: '2024-01-22T13:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the argument was last modified', example: '2024-01-25T10:30:00Z' }
      },
      required: %w[id title projekt_phase_id created_at updated_at]
    }.freeze

    IFRAME_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the embedded iframe', example: 1 },
        title: { type: :string, nullable: true, description: 'Optional title for the iframe block', example: 'Interactive Map' },
        url: { type: :string, description: 'The URL to be embedded in the iframe', example: 'https://example.com/map' },
        description: { type: :string, nullable: true, description: 'Description of what the iframe content shows', example: 'Interactive map showing project locations' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this iframe belongs to', example: 8 },
        width: { type: :integer, nullable: true, description: 'Width of the iframe in pixels', example: 800 },
        height: { type: :integer, nullable: true, description: 'Height of the iframe in pixels', example: 600 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the iframe was created', example: '2024-01-16T09:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the iframe was last modified', example: '2024-01-18T14:00:00Z' }
      },
      required: %w[id url projekt_phase_id created_at updated_at]
    }.freeze

    PAGINATION_RESPONSE_SCHEMA = {
      type: :object,
      properties: {
        current_page: { type: :integer },
        total_pages: { type: :integer },
        total_count: { type: :integer },
        per_page: { type: :integer }
      }
    }.freeze

    def self.all
      {
        Argument: ARGUMENT_SCHEMA,
        Iframe: IFRAME_SCHEMA
      }
    end
  end
end
