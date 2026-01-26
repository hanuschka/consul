# frozen_string_literal: true

module Schemas
  module PointOfInterest
    POINT_OF_INTEREST_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the category', example: 1 },
        name: { type: :string, description: 'The name of the category', example: 'Public Services' },
        description: { type: :string, nullable: true, description: 'Description of what this category includes', example: 'Government offices, libraries, community centers' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    POINT_OF_INTEREST_PIN_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the point of interest pin', example: 1 },
        title: { type: :string, description: 'The name or title of the location', example: 'Central Library' },
        description: { type: :string, nullable: true, description: 'Description of the point of interest', example: 'Main public library with reading rooms and meeting spaces' },
        latitude: { type: :number, description: 'Geographic latitude coordinate', example: 40.7128 },
        longitude: { type: :number, description: 'Geographic longitude coordinate', example: -74.0060 },
        category_id: { type: :integer, nullable: true, description: 'ID of the point of interest category', example: 5 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this pin belongs to', example: 12 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the pin was created', example: '2024-01-05T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the pin was last modified', example: '2024-01-12T11:30:00Z' },
        category: {
          type: :object,
          nullable: true,
          description: 'The category object if populated',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, description: 'Category name' }
          }
        }
      },
      required: %w[id title latitude longitude projekt_phase_id created_at updated_at]
    }.freeze

    def self.all
      {
        PointOfInterestCategory: POINT_OF_INTEREST_CATEGORY_SCHEMA,
        PointOfInterestPin: POINT_OF_INTEREST_PIN_SCHEMA
      }
    end
  end
end
