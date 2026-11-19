# frozen_string_literal: true

module Schemas
  module PointOfInterest
    PROJEKT_PHASE_REFERENCE = {
      type: :object,
      description: 'The phase the record belongs to',
      properties: {
        id: { type: :integer, example: 12 },
        title: { type: :string, nullable: true, example: 'Orte' },
        type: { type: :string, example: 'ProjektPhase::PointOfInterestPhase' },
        projekt_id: { type: :integer, example: 3 }
      },
      additionalProperties: false
    }.freeze

    PROJEKT_REFERENCE = {
      type: :object,
      description: 'The projekt of the phase',
      properties: {
        id: { type: :integer, example: 3 },
        title: { type: :string, nullable: true, example: 'Marktplatz' }
      },
      additionalProperties: false
    }.freeze

    POINT_OF_INTEREST_CATEGORY_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the category', example: 1 },
        name: { type: :string, description: 'The name of the category', example: 'Public Services' },
        color: { type: :string, description: 'Colour of the category pins as a hex code', example: '#004a83' },
        icon: { type: :string, description: 'Font Awesome icon name of the category pins', example: 'landmark' },
        icon_image_url: { type: :string, nullable: true, description: 'URL of the uploaded icon image that replaces the Font Awesome icon on the map (set by the Masterportal sync). Read-only.', example: 'https://example.com/rails/active_storage/blobs/icon.svg' },
        position: { type: :integer, description: 'Display order among the categories of the phase (lower first)', example: 0 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase the category belongs to', example: 12 },
        projekt_phase: PROJEKT_PHASE_REFERENCE,
        projekt: PROJEKT_REFERENCE,
        pins_count: { type: :integer, description: 'Number of pins in the category', example: 8 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the category was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the category was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id name color icon position projekt_phase_id pins_count created_at updated_at],
      additionalProperties: false
    }.freeze

    POINT_OF_INTEREST_CATEGORY_WRITE_PARAMS = {
      type: :object,
      properties: {
        projekt_point_of_interest_category: {
          type: :object,
          properties: {
            name: { type: :string, description: 'Category name. Required on create.' },
            color: { type: :string, description: 'Hex colour of the pins. Required on create.', example: '#004a83' },
            icon: { type: :string, description: 'Font Awesome icon name. Required on create.', example: 'landmark' },
            position: { type: :integer, description: 'Display order among the categories of the phase', example: 1 }
          }
        }
      },
      required: ['projekt_point_of_interest_category']
    }.freeze

    POINT_OF_INTEREST_PIN_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the point of interest pin', example: 1 },
        description: { type: :string, nullable: true, description: 'Description in the current language', example: 'Main public library with reading rooms' },
        translations: Schemas::Miscellaneous.translations_schema(%w[description]),
        projekt_point_of_interest_category_id: { type: :integer, nullable: true, description: 'ID of the point of interest category', example: 5 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this pin belongs to', example: 12 },
        **Schemas::Miscellaneous::EXTERNAL_REFERENCE_PROPERTIES,
        map_location: { '$ref' => '#/components/schemas/MapLocation' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the pin. Only returned to admin clients.', example: 15 },
        author: { '$ref' => '#/components/schemas/Author' },
        category: {
          type: :object,
          description: 'The category of the pin',
          properties: {
            id: { type: :integer, description: 'Category ID' },
            name: { type: :string, description: 'Category name' },
            color: { type: :string, description: 'Category colour' },
            icon: { type: :string, description: 'Category icon' }
          },
          additionalProperties: false
        },
        projekt_phase: PROJEKT_PHASE_REFERENCE,
        projekt: PROJEKT_REFERENCE,
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the pin was created', example: '2024-01-05T10:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the pin was last modified', example: '2024-01-12T11:30:00Z' }
      },
      required: %w[id translations projekt_phase_id external_source external_id map_location created_at updated_at],
      additionalProperties: false
    }.freeze

    PIN_EXTERNAL_REFERENCE_WRITE_PROPERTIES =
      Schemas::Miscellaneous::EXTERNAL_REFERENCE_WRITE_PROPERTIES.transform_values { |property|
        property.merge(description: "#{property[:description]} Only taken on create.")
      }.freeze

    POINT_OF_INTEREST_PIN_WRITE_PARAMS = {
      type: :object,
      properties: {
        projekt_point_of_interest_pin: {
          type: :object,
          properties: {
            description: { type: :string, description: 'Description in the current language' },
            translations: Schemas::Miscellaneous.translations_schema(%w[description]),
            projekt_point_of_interest_category_id: { type: :integer, description: 'ID of a category of the same phase' },
            **PIN_EXTERNAL_REFERENCE_WRITE_PROPERTIES,
            map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' }
          }
        }
      },
      required: ['projekt_point_of_interest_pin']
    }.freeze

    def self.all
      {
        PointOfInterestCategory: POINT_OF_INTEREST_CATEGORY_SCHEMA,
        PointOfInterestCategoryWriteParams: POINT_OF_INTEREST_CATEGORY_WRITE_PARAMS,
        PointOfInterestPin: POINT_OF_INTEREST_PIN_SCHEMA,
        PointOfInterestPinWriteParams: POINT_OF_INTEREST_PIN_WRITE_PARAMS
      }
    end
  end
end
