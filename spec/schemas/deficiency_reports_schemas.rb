# frozen_string_literal: true

module Schemas
  module DeficiencyReports
    DEFICIENCY_REPORT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the deficiency report', example: 1 },
        title: { type: :string, description: 'Title or summary of the deficiency/issue', example: 'Pothole on Main Street' },
        description: { type: :string, nullable: true, description: 'Detailed description of the deficiency', example: 'Large pothole causing safety concerns near intersection' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who reported the deficiency', example: 18 },
        category_id: { type: :integer, nullable: true, description: 'ID of the deficiency report category', example: 3 },
        status_id: { type: :integer, nullable: true, description: 'ID of the current status (open, in_progress, resolved, etc.)', example: 1 },
        location: { type: :string, nullable: true, description: 'Physical location or address of the deficiency', example: 'Main Street at 5th Avenue' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the report was created', example: '2024-01-20T14:30:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the report was last modified', example: '2024-01-22T10:15:00Z' },
        category: {
          type: :object,
          nullable: true,
          description: 'The category object if populated',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, description: 'Category name' }
          }
        },
        status: {
          type: :object,
          nullable: true,
          description: 'The status object if populated',
          properties: {
            id: { type: :integer, description: 'Status ID' },
            title: { type: :string, description: 'Status title' }
          }
        },
        image: { '$ref' => '#/components/schemas/ImageResponse' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    DEFICIENCY_REPORT_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the category', example: 1 },
        name: { type: :string, description: 'The name of the deficiency report category', example: 'Infrastructure' },
        description: { type: :string, nullable: true, description: 'Description of what types of reports fit in this category', example: 'Reports about roads, bridges, utilities' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    IMAGE_ATTRIBUTES_SCHEMA = {
      type: :object,
      properties: {
        title: { type: :string, nullable: true, description: 'Title or caption for the image' },
        attachment: { type: :string, description: 'Base64-encoded image data' },
        credits: { type: :string, nullable: true, description: 'Attribution or credits for the image' },
        ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
        _destroy: { type: :boolean, nullable: true, description: 'Flag to delete the image' }
      }
    }.freeze

    def self.all
      {
        DeficiencyReport: DEFICIENCY_REPORT_SCHEMA,
        DeficiencyReportCategory: DEFICIENCY_REPORT_CATEGORY_SCHEMA,
        ImageAttributes: IMAGE_ATTRIBUTES_SCHEMA
      }
    end
  end
end
