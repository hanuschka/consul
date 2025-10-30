# frozen_string_literal: true

module Schemas
  module Projekts
    # Projekt schema definition for OpenAPI/Swagger documentation
    PROJEKT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        name: { type: :string, example: 'Sample Projekt' },
        parent_id: { type: :integer, nullable: true, example: nil },
        created_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' },
        order_number: { type: :integer, nullable: true, example: 1 },
        total_duration_start: { type: :string, format: :datetime, nullable: true, example: '2024-01-01T00:00:00Z' },
        total_duration_end: { type: :string, format: :datetime, nullable: true, example: '2024-12-31T23:59:59Z' },
        comments_count: { type: :integer, nullable: true, example: 0 },
        geozone_affiliated: { type: [:boolean, :string], nullable: true, example: false },
        level: { type: :integer, nullable: true, example: 0 },
        show_start_date_in_frontend: { type: [:boolean, :string], nullable: true, example: true },
        show_end_date_in_frontend: { type: [:boolean, :string], nullable: true, example: true },
        top_level_projekt_id: { type: :integer, nullable: true, example: nil },
        tsv: { type: :string, nullable: true, example: nil },
        preview_code: { type: :string, nullable: true, example: 'abc123' },
        site_customization_page: {
          type: :object,
          nullable: true,
          properties: {
            title: { type: :string, nullable: true, example: 'Sample Projekt Page' },
            slug: { type: :string, nullable: true, example: 'sample-projekt' }
          }
        },
        projekt_settings: {
          type: :array,
          items: {
            type: :object,
            properties: {
              key: { type: :string, example: 'show_map' },
              value: { type: :string, nullable: true, example: 'true' }
            }
          },
          example: [
            { key: 'show_map', value: 'true' },
            { key: 'enable_comments', value: 'false' }
          ]
        },
        projekt_phases: {
          type: :array,
          items: { '$ref' => '#/components/schemas/ProjektPhase' }
        },
        content_blocks: {
          type: :array,
          items: { '$ref' => '#/components/schemas/ContentBlock' }
        }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    # ProjektPhase schema definition for OpenAPI/Swagger documentation
    PROJEKT_PHASE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        phase_tab_name: { type: :string, example: 'Planning Phase' },
        type: { type: :string, example: 'ProjektPhase::InformationPhase' },
        projekt_id: { type: :integer, example: 1 },
        active: { type: :boolean, example: true },
        visible: { type: :boolean, example: true },
        position: { type: :integer, example: 0 },
        start_date: { type: :string, format: :datetime, nullable: true, example: '2024-01-01T00:00:00Z' },
        end_date: { type: :string, format: :datetime, nullable: true, example: '2024-03-31T23:59:59Z' },
        created_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id phase_tab_name type projekt_id]
    }.freeze

    # ProjektPhaseSetting schema definition for OpenAPI/Swagger documentation
    PROJEKT_PHASE_SETTING_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        key: { type: :string, example: 'feature.general.newest_first' },
        value: { type: :string, nullable: true, example: 'active' }
      },
      required: %w[id key]
    }.freeze

    # ContentBlock schema definition for OpenAPI/Swagger documentation
    CONTENT_BLOCK_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        title: { type: :string, nullable: true, example: 'Introduction' },
        body: { type: :string, nullable: true, example: 'This is the content of the block.' },
        locale: { type: :string, example: 'en' },
        position: { type: :integer, example: 0 },
        blockable_type: { type: :string, example: 'Projekt' },
        blockable_id: { type: :integer, example: 1 },
        created_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id position blockable_type blockable_id]
    }.freeze

    # All schemas combined for easy reference in swagger_helper
    def self.all
      {
        Projekt: PROJEKT_SCHEMA,
        ProjektPhase: PROJEKT_PHASE_SCHEMA,
        ContentBlock: CONTENT_BLOCK_SCHEMA,
        ProjektPhaseSetting: PROJEKT_PHASE_SETTING_SCHEMA
      }
    end
  end
end

