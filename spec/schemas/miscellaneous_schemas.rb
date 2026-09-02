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
        ai_generated: { type: :boolean, description: 'True when the image was created or edited with AI. Drives the visible AI disclosure label on public pages.', example: false },
        url: { type: :string, description: 'Full URL to the image', example: 'https://example.com/uploads/image.jpg' },
        variants: {
          type: :object,
          nullable: true,
          description: "Pre-generated resized versions of the image, keyed by their target maximum width in pixels (plus 'original'). Each numeric key is a variant scaled to fit within that width: the width is the upper bound, height scales proportionally so the aspect ratio is preserved, and the image is never enlarged beyond its original size (a source narrower than the key yields the smaller source dimensions, not an upscaled image). Pick the key closest to (and at least as large as) the width you will render at. By default every version is returned. The projekts list (index) endpoint accepts an 'image_variant_versions' query parameter (comma-separated, e.g. '300,900') to restrict this object to specific versions and shrink the payload; in that case only the requested keys are present.",
          properties: {
            "150": { type: :string, nullable: true, description: 'Max 150px wide. Thumbnail (avatars, list rows, tight grids).', example: 'https://example.com/uploads/150.jpg' },
            "300": { type: :string, nullable: true, description: 'Max 300px wide. Small (card teasers, mobile inline images).', example: 'https://example.com/uploads/300.jpg' },
            "450": { type: :string, nullable: true, description: 'Max 450px wide. Medium (sidebar, two-column card images).', example: 'https://example.com/uploads/450.jpg' },
            "600": { type: :string, nullable: true, description: 'Max 600px wide. Medium-large (single-column body images).', example: 'https://example.com/uploads/600.jpg' },
            "900": { type: :string, nullable: true, description: 'Max 900px wide. Large (wide content area, retina cards).', example: 'https://example.com/uploads/900.jpg' },
            "1200": { type: :string, nullable: true, description: 'Max 1200px wide. Extra large (page headers, hero on desktop).', example: 'https://example.com/uploads/1200.jpg' },
            "1920": { type: :string, nullable: true, description: 'Max 1920px wide. Full-width Full HD (full-bleed banners, retina hero).', example: 'https://example.com/uploads/1920.jpg' },
            "original": { type: :string, nullable: true, description: 'The unmodified uploaded file at its original dimensions (no resizing). Largest payload; use only when the exact source is required.', example: 'https://example.com/uploads/original.jpg' }
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
