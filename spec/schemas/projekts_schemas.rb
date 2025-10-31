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
        page: {
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

    # Shared image attributes schema for API (matches image_attributes_api)
    IMAGE_ATTRIBUTES_API_SCHEMA = {
      type: :object,
      description: 'Attributes for updating the projekt page image. Provide attachment (base64-encoded)/title/credits to create/update, or _destroy=true to remove the image. Defaults: _destroy=false.',
      properties: {
        title: {
          type: :string,
          nullable: true,
          description: 'Human-readable title/alt text for the image. Optional.',
          example: 'Cover Image Title'
        },
        attachment: {
          type: :string,
          nullable: true,
          description: 'Base64-encoded image file data. Supported formats: JPEG, PNG, GIF, WebP. Example: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="'
        },
        credits: {
          type: :string,
          nullable: true,
          description: 'Attribution/credits for the image. Optional.',
          example: 'Photo by John Doe'
        },
        _destroy: {
          type: :boolean,
          nullable: true,
          default: false,
          description: 'If true, deletes the current projekt page image. Default: false.',
          example: false
        }
      }
    }.freeze

    # Request body schema for updating projekt page image (flat body, no wrapper)
    PROJEKT_IMAGE_UPDATE_PARAMS = {
      type: :object,
      description: 'Body for updating projekt page image. Provide attachment/title/credits to create/update, or _destroy=true to remove. Defaults: _destroy=false.',
      properties: {
        image: { '$ref' => '#/components/schemas/ImageAttributesApi' }
      },
      required: ['image']
    }.freeze

    # Request body schema: create projekt
    PROJEKT_CREATE_PARAMS = {
      type: :object,
      properties: {
        projekt: {
          type: :object,
          properties: {
            name: { type: :string },
            parent_id: { type: :integer, nullable: true },
            total_duration_start: { type: :string, format: :date_time, nullable: true },
            total_duration_end: { type: :string, format: :date_time, nullable: true },
            show_start_date_in_frontend: { type: :boolean },
            show_end_date_in_frontend: { type: :boolean },
            geozone_affiliated: { type: :boolean },
            order_number: { type: :integer, nullable: true },
            tag_list: { type: :string, nullable: true },
            related_sdg_list: { type: :string, nullable: true },
            landing_page_ids: { type: :array, items: { type: :integer } },
            geozone_affiliation_ids: { type: :array, items: { type: :integer } },
            sdg_goal_ids: { type: :array, items: { type: :integer } },
            individual_group_value_ids: { type: :array, items: { type: :integer } },
            map_location_attributes: {
              type: :object,
              properties: {
                latitude: { type: :number },
                longitude: { type: :number },
                zoom: { type: :integer }
              }
            },
            # page updates are handled via dedicated endpoints
            projekt_manager_assignments_attributes: {
              type: :array,
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, nullable: true },
                  projekt_manager_id: { type: :integer },
                  projekt_id: { type: :integer },
                  permissions: { type: :array, items: { type: :string } }
                }
              }
            }
          },
          required: ['name']
        }
      },
      required: ['projekt']
    }.freeze

    # Request body schema: update projekt (same fields as create, all optional)
    PROJEKT_UPDATE_PARAMS = {
      type: :object,
      properties: {
        projekt: {
          type: :object,
          properties: PROJEKT_CREATE_PARAMS[:properties][:projekt][:properties]
        }
      },
      required: ['projekt']
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

    # Poll schema definition for OpenAPI/Swagger documentation
    POLL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        name: { type: :string, example: 'Community Vote' },
        summary: { type: :string, nullable: true, example: 'Summary' },
        description: { type: :string, nullable: true, example: 'Description' },
        starts_at: { type: :string, format: :date_time, nullable: true, example: '2025-01-01T00:00:00Z' },
        ends_at: { type: :string, format: :date_time, nullable: true, example: '2025-01-31T23:59:59Z' },
        geozone_restricted: { type: :boolean, nullable: true, example: false },
        budget_id: { type: :integer, nullable: true, example: 1 },
        created_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' },
        geozones: {
          type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              name: { type: :string }
            }
          }
        },
        budget: {
          type: :object,
          nullable: true,
          properties: {
            id: { type: :integer },
            name: { type: :string }
          }
        },
        questions: {
          type: :array,
          items: {
            type: :object,
            properties: {
              id: { type: :integer },
              title: { type: :string }
            }
          }
        }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    # ProjektEvent schema definition
    PROJEKT_EVENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        title: { type: :string, example: 'Town Hall' },
        description: { type: :string, nullable: true, example: 'Discussion on city planning' },
        datetime: { type: :string, format: :date_time, nullable: true, example: '2025-02-01T18:00:00Z' },
        end_datetime: { type: :string, format: :date_time, nullable: true, example: '2025-02-01T20:00:00Z' },
        location: { type: :string, nullable: true, example: 'City Hall' },
        registration_url: { type: :string, nullable: true, example: 'https://example.com/register' },
        projekt_phase_id: { type: :integer, example: 10 },
        created_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    # ProjektNotification schema definition
    PROJEKT_NOTIFICATION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 1 },
        title: { type: :string, example: 'Update' },
        body: { type: :string, nullable: true, example: 'We have news' },
        link_text: { type: :string, nullable: true, example: 'Read more' },
        link_url: { type: :string, nullable: true, example: 'https://example.com' },
        segment_recipient: { type: :string, nullable: true, example: 'all' },
        projekt_phase_id: { type: :integer, example: 10 },
        created_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, example: '2025-01-01T00:00:00Z' }
      },
      required: %w[id title created_at updated_at]
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
        ImageAttributesApi: IMAGE_ATTRIBUTES_API_SCHEMA,
        ProjektImageUpdateParams: PROJEKT_IMAGE_UPDATE_PARAMS,
        ProjektCreateParams: PROJEKT_CREATE_PARAMS,
        ProjektUpdateParams: PROJEKT_UPDATE_PARAMS,
        ProjektPhase: PROJEKT_PHASE_SCHEMA,
        ContentBlock: CONTENT_BLOCK_SCHEMA,
        ProjektPhaseSetting: PROJEKT_PHASE_SETTING_SCHEMA,
        Poll: POLL_SCHEMA,
        ProjektEvent: PROJEKT_EVENT_SCHEMA,
        ProjektNotification: PROJEKT_NOTIFICATION_SCHEMA
      }
    end
  end
end

