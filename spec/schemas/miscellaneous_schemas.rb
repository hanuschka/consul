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
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the argument was last modified', example: '2024-01-25T10:30:00Z' },
        image: { '$ref' => '#/components/schemas/ImageResponse' }
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

    NO_PAGINATION_RESPONSE_SCHEMA = {
      type: :object,
      description: 'Returned in place of pagination metadata when no pagination was applied (all matching records returned in a single response). Supply the page and/or per_page query parameters to paginate.',
      properties: {
        message: {
          type: :string,
          description: 'Help text stating that all records were returned without pagination and how to enable it.',
          example: "All matching records were returned in a single response without pagination. To paginate, supply the 'page' and/or 'per_page' query parameters (for example: ?page=1&per_page=20)."
        }
      },
      required: ['message']
    }.freeze

    IMAGE_RESPONSE_SCHEMA = {
      type: :object,
      nullable: true,
      description: 'Image associated with the resource',
      properties: {
        id: { type: :integer, description: 'Image ID', example: 1 },
        title: { type: :string, nullable: true, description: 'Image title or alt text', example: 'Cover Image' },
        credits: { type: :string, nullable: true, description: 'Image attribution or credits', example: 'Photo by John Doe' },
        url: { type: :string, description: 'Full URL to the image', example: 'https://example.com/uploads/image.jpg' },
        variants: {
          type: :object,
          nullable: true,
          description: 'Different sized versions of the image with width-based keys',
          properties: {
            "150": { type: :string, nullable: true, description: 'Thumbnail 150px width', example: 'https://example.com/uploads/150.jpg' },
            "300": { type: :string, nullable: true, description: 'Small 300px width', example: 'https://example.com/uploads/300.jpg' },
            "450": { type: :string, nullable: true, description: 'Medium 450px width', example: 'https://example.com/uploads/450.jpg' },
            "600": { type: :string, nullable: true, description: 'Medium-large 600px width', example: 'https://example.com/uploads/600.jpg' },
            "900": { type: :string, nullable: true, description: 'Large 900px width', example: 'https://example.com/uploads/900.jpg' },
            "1200": { type: :string, nullable: true, description: 'Extra large 1200px width', example: 'https://example.com/uploads/1200.jpg' },
            "1920": { type: :string, nullable: true, description: 'Full HD 1920px width', example: 'https://example.com/uploads/1920.jpg' },
            "original": { type: :string, nullable: true, description: 'Original unmodified image', example: 'https://example.com/uploads/original.jpg' }
          }
        }
      }
    }.freeze

    def self.all
      {
        Argument: ARGUMENT_SCHEMA,
        Iframe: IFRAME_SCHEMA,
        ImageResponse: IMAGE_RESPONSE_SCHEMA
      }
    end
  end
end
