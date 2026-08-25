# frozen_string_literal: true

module Schemas
  module Projekts
    # Projekt schema definition for OpenAPI/Swagger documentation
    PROJEKT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the projekt', example: 1 },
        name: { type: :string, description: 'The name or title of the projekt', example: 'Sample Projekt' },
        title: { type: :string, nullable: true, description: 'The projekt page title (same value as page.title), exposed at the top level for convenience.', example: 'Sample Projekt Page' },
        subtitle: { type: :string, nullable: true, description: 'The projekt page subtitle (same value as page.subtitle).', example: 'A short tagline for the projekt' },
        image: { '$ref' => '#/components/schemas/Image' },
        text: { type: :string, description: 'The full projekt page content: the body of all content blocks (ordered by position) combined into a single string. Same value as text_html (already sanitized at save time, not re-processed here). Only present when include_text=true on the list endpoint; always present in the single projekt response. Empty string when the projekt has no content blocks.', example: '<h2>Welcome</h2><p>About this projekt.</p>' },
        text_html: { type: :string, description: 'The full projekt page content as HTML: the body of all content blocks (ordered by position) combined into a single string. Only present when include_text=true on the list endpoint; always present in the single projekt response. Empty string when the projekt has no content blocks.', example: '<h2>Welcome</h2><p>About this projekt.</p>' },
        parent_id: { type: :integer, nullable: true, description: 'ID of the parent projekt if this is a sub-projekt. Null if this is a top-level projekt.', example: nil },
        created_at: { type: :string, format: :datetime, description: 'Timestamp when the projekt was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, description: 'Timestamp when the projekt was last modified', example: '2024-01-01T00:00:00Z' },
        order_number: { type: :integer, nullable: true, description: 'The display order of this projekt among its siblings. Lower numbers appear first.', example: 1 },
        total_duration_start: { type: :string, format: :datetime, nullable: true, description: 'The project start date. When set, this defines when the projekt begins.', example: '2024-01-01T00:00:00Z' },
        total_duration_end: { type: :string, format: :datetime, nullable: true, description: 'The project end date. When set, this defines when the projekt concludes.', example: '2024-12-31T23:59:59Z' },
        comments_count: { type: :integer, nullable: true, description: 'The total number of comments on the projekt', example: 0 },
        geozone_affiliated: { type: [:boolean, :string], nullable: true, description: 'Indicates if the projekt is restricted to specific geographic zones', example: false },
        level: { type: :integer, nullable: true, description: 'The hierarchy level of the projekt. Level 0 is a top-level projekt, higher numbers indicate deeper nesting.', example: 0 },
        show_start_date_in_frontend: { type: [:boolean, :string], nullable: true, description: 'Whether to display the project start date on the frontend', example: true },
        show_end_date_in_frontend: { type: [:boolean, :string], nullable: true, description: 'Whether to display the project end date on the frontend', example: true },
        top_level_projekt_id: { type: :integer, nullable: true, description: 'ID of the top-level projekt in the hierarchy. Null if this is the top level.', example: nil },
        preview_code: { type: :string, nullable: true, description: 'A unique code used for generating preview links to the projekt before publication', example: 'abc123' },
        page: {
          type: :object,
          nullable: true,
          description: 'The associated Projekt page containing content and metadata',
          properties: {
            title: { type: :string, nullable: true, description: 'The page title displayed in the frontend', example: 'Sample Projekt Page' },
            slug: { type: :string, nullable: true, description: 'URL-friendly identifier for the page', example: 'sample-projekt' },
            image: { '$ref' => '#/components/schemas/Image' }
          }
        },
        projekt_settings: {
          type: :array,
          description: 'Configuration settings for the projekt as key-value pairs. Only present when include_projekt_settings=true on the list endpoint; always present in the single projekt response.',
          items: {
            type: :object,
            properties: {
              key: { type: :string, description: 'Setting identifier (e.g., show_map, enable_comments)', example: 'show_map' },
              value: { type: :string, nullable: true, description: 'Setting value (e.g., true, false, or other values)', example: 'true' }
            }
          },
          example: [
            { key: 'show_map', value: 'true' },
            { key: 'enable_comments', value: 'false' }
          ]
        },
        projekt_phases: {
          type: :array,
          description: 'Array of phases this projekt contains (e.g., Comment phase, Voting phase)',
          items: { '$ref' => '#/components/schemas/ProjektPhase' }
        },
        content_blocks: {
          type: :array,
          description: 'Array of content blocks that compose the projekt page content',
          items: { '$ref' => '#/components/schemas/ContentBlock' }
        }
      },
      required: %w[id name created_at updated_at]
    }.freeze

    # Image response schema (matches ImageSerializer with include_variants: true)
    IMAGE_SCHEMA = {
      type: :object,
      nullable: true,
      description: 'An attached image (e.g. the projekt banner/cover) with its responsive variants.',
      properties: {
        id: { type: :integer, description: 'Unique identifier for the image', example: 1 },
        title: { type: :string, nullable: true, description: 'Image title or alt text', example: 'Cover Image' },
        credits: { type: :string, nullable: true, description: 'Image attribution or credits', example: 'Photo by John Doe' },
        ai_generated: { type: :boolean, description: 'True when the image was created or edited with AI. Drives the visible AI disclosure label on public pages.', example: false },
        url: { type: :string, description: 'URL to the original full-size image', example: 'https://example.com/images/page-image.jpg' },
        variants: {
          type: :object,
          description: 'URLs of resized variants keyed by maximum width in pixels, plus the original.',
          properties: {
            "150": { type: :string, nullable: true, description: 'Variant limited to 150px width', example: 'https://example.com/images/page-image-150.jpg' },
            "300": { type: :string, nullable: true, description: 'Variant limited to 300px width', example: 'https://example.com/images/page-image-300.jpg' },
            "450": { type: :string, nullable: true, description: 'Variant limited to 450px width', example: 'https://example.com/images/page-image-450.jpg' },
            "600": { type: :string, nullable: true, description: 'Variant limited to 600px width', example: 'https://example.com/images/page-image-600.jpg' },
            "900": { type: :string, nullable: true, description: 'Variant limited to 900px width', example: 'https://example.com/images/page-image-900.jpg' },
            "1200": { type: :string, nullable: true, description: 'Variant limited to 1200px width', example: 'https://example.com/images/page-image-1200.jpg' },
            "1920": { type: :string, nullable: true, description: 'Variant limited to 1920px width', example: 'https://example.com/images/page-image-1920.jpg' },
            original: { type: :string, description: 'URL to the original full-size image', example: 'https://example.com/images/page-image.jpg' }
          }
        }
      }
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
        ai_generated: {
          type: :boolean,
          nullable: true,
          default: false,
          description: 'Set to true when the image was created or edited with AI. The public page then shows the AI disclosure label. Resets to false when the attachment is replaced without passing it again. Default: false.',
          example: false
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
          description: 'Projekt data for creation',
          properties: {
            name: { type: :string, description: 'The name or title of the projekt (required)' },
            parent_id: { type: :integer, nullable: true, description: 'ID of the parent projekt if creating a sub-projekt. Omit for top-level projekts.' },
            total_duration_start: { type: :string, format: :date_time, nullable: true, description: 'Project start date (ISO 8601 format). Omit for no start date.' },
            total_duration_end: { type: :string, format: :date_time, nullable: true, description: 'Project end date (ISO 8601 format). Omit for no end date.' },
            show_start_date_in_frontend: { type: :boolean, description: 'Whether to display the start date on the frontend' },
            show_end_date_in_frontend: { type: :boolean, description: 'Whether to display the end date on the frontend' },
            geozone_affiliated: { type: :boolean, description: 'Whether this projekt is restricted to specific geographic zones' },
            order_number: { type: :integer, nullable: true, description: 'Display order among sibling projekts. Lower numbers appear first. Omit for default ordering.' },
            tag_list: { type: :string, nullable: true, description: 'Comma-separated list of tags for categorization (e.g., "environment,infrastructure")' },
            related_sdg_list: { type: :string, nullable: true, description: 'Comma-separated list of related Sustainable Development Goal IDs' },
            landing_page_id: { type: :integer, nullable: true, description: 'ID of the landing page associated with this projekt' },
            geozone_affiliation_ids: { type: :array, items: { type: :integer }, description: 'Array of geographic zone IDs this projekt belongs to' },
            sdg_goal_ids: { type: :array, items: { type: :integer }, description: 'Array of Sustainable Development Goal IDs this projekt aligns with' },
            individual_group_value_ids: { type: :array, items: { type: :integer }, description: 'Array of individual group/demographic IDs with special restrictions or access' },
            map_location_attributes: {
              type: :object,
              description: 'Geographic coordinates and zoom level for map display',
              properties: {
                latitude: { type: :number, description: 'Latitude coordinate (-90 to 90)' },
                longitude: { type: :number, description: 'Longitude coordinate (-180 to 180)' },
                zoom: { type: :integer, description: 'Map zoom level (0-18, where 0 is world view)' }
              }
            },
            projekt_manager_assignments_attributes: {
              type: :array,
              description: 'Array of projekt manager role assignments. Omit if no managers need to be assigned.',
              items: {
                type: :object,
                properties: {
                  id: { type: :integer, nullable: true, description: 'ID of existing assignment when updating. Omit for new assignments.' },
                  projekt_manager_id: { type: :integer, description: 'ID of the user to assign as projekt manager' },
                  projekt_id: { type: :integer, description: 'ID of the projekt (set by API)' },
                  permissions: { type: :array, items: { type: :string }, description: 'Array of permission names (e.g., ["admin", "edit", "view"])' }
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
        id: { type: :integer, description: 'Unique identifier for the projekt phase', example: 1 },
        phase_tab_name: { type: :string, description: 'The display name of the phase shown in the frontend interface', example: 'Planning Phase' },
        type: {
          type: :string,
          description: 'The phase type determining what kind of participation or content is available during this phase',
          example: 'ProjektPhase::CommentPhase',
          enum: [
            'ProjektPhase::CommentPhase',
            'ProjektPhase::ProposalPhase',
            'ProjektPhase::QuestionPhase',
            'ProjektPhase::VotingPhase',
            'ProjektPhase::BudgetPhase',
            'ProjektPhase::LegislationPhase',
            'ProjektPhase::FormularPhase',
            'ProjektPhase::LivestreamPhase',
            'ProjektPhase::MilestonePhase',
            'ProjektPhase::ProjektNotificationPhase',
            'ProjektPhase::EventPhase',
            'ProjektPhase::ArgumentPhase',
            'ProjektPhase::NewsfeedPhase',
            'ProjektPhase::IframePhase',
            'ProjektPhase::PointOfInterestPhase'
          ]
        },
        projekt_id: { type: :integer, description: 'ID of the projekt this phase belongs to', example: 1 },
        active: { type: :boolean, description: 'Whether the phase is currently active and allowing participation', example: true },
        visible: { type: :boolean, description: 'Whether the phase is visible to users on the frontend', example: true },
        position: { type: :integer, description: 'The display order of this phase among other phases in the projekt. Lower numbers appear first.', example: 0 },
        start_date: { type: :string, format: :datetime, nullable: true, description: 'When the phase becomes active. Null means no start date restriction.', example: '2024-01-01T00:00:00Z' },
        end_date: { type: :string, format: :datetime, nullable: true, description: 'When the phase becomes inactive. Null means no end date restriction.', example: '2024-03-31T23:59:59Z' },
        created_at: { type: :string, format: :datetime, description: 'Timestamp when the phase was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, description: 'Timestamp when the phase was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id phase_tab_name type projekt_id]
    }.freeze

    # ProjektPhase request schema for create/update operations
    PROJEKT_PHASE_REQUEST_SCHEMA = {
      type: :object,
      properties: {
        type: {
          type: :string,
          example: 'ProjektPhase::CommentPhase',
          enum: ProjektPhase::PROJEKT_PHASES_TYPES,
          description: 'The type of projekt phase that determines what kind of participation or content is available. Regular phases: CommentPhase (discussion/feedback), ProposalPhase (citizen proposals), QuestionPhase (Q&A), VotingPhase (polls/voting), BudgetPhase (participatory budgeting), LegislationPhase (legislative process), FormularPhase (forms/surveys). Special phases: LivestreamPhase (live streaming), MilestonePhase (timeline milestones), ProjektNotificationPhase (announcements), EventPhase (events/meetings), ArgumentPhase (pro/con arguments), NewsfeedPhase (news feed), IframePhase (embedded content), PointOfInterestPhase (map pins). Required for creation.'
        },
        start_date: {
          type: :string,
          format: :date,
          nullable: true,
          description: 'The date when the phase becomes active and participation begins (YYYY-MM-DD format). If null, the phase can be activated immediately via the active flag. Must be before end_date if both are provided. Used to schedule phases in advance.'
        },
        end_date: {
          type: :string,
          format: :date,
          nullable: true,
          description: 'The date when the phase becomes inactive and participation ends (YYYY-MM-DD format). If null, the phase continues indefinitely until manually deactivated. Must be after start_date if both are provided. After this date, users can no longer submit new content but existing content remains visible.'
        },
        active: {
          type: :boolean,
          description: 'Whether the phase is currently active and allowing participation. When true, users can interact with the phase (submit comments, proposals, vote, etc.) based on other restrictions. When false, the phase is inactive regardless of date settings. Defaults to false if not specified.'
        },
        frontend_visibility: {
          type: :boolean,
          description: 'Whether the phase is visible to users on the frontend interface. When true, the phase appears in navigation tabs and phase listings. When false, the phase is hidden from public view but may still be accessible via direct links or admin interfaces. Useful for preparing phases before public launch. Defaults to true.'
        },
        given_order: {
          type: :integer,
          nullable: true,
          description: 'The display order/position of this phase among other phases in the projekt. Lower numbers appear first in phase navigation and listings. If null, phases are ordered by creation date. Use this to control the sequence in which phases appear to users (e.g., planning phase before voting phase).'
        },
        geozone_restricted: {
          type: :boolean,
          description: 'Whether participation in this phase is restricted to specific geographic zones. When true, only users from geozones listed in geozone_restriction_ids can participate. When false, all users can participate (subject to other restrictions). Must be true if geozone_restriction_ids is provided.'
        },
        age_range_id: {
          type: :integer,
          nullable: true,
          description: 'ID of an age range restriction that limits participation to users within a specific age group. If null, there is no age restriction. Age ranges are predefined categories (e.g., "18-25", "26-35", "65+") used to ensure age-appropriate participation or comply with legal requirements.'
        },
        user_status: {
          type: :string,
          nullable: true,
          description: 'Minimum user status required to participate in this phase. Valid values: "guest" (anyone, including anonymous), "registered" (must be logged in), "verified" (must have verified account). If null, defaults to "registered". Higher verification levels ensure more trusted participation but may reduce engagement.'
        },
        lock_on: {
          type: :string,
          format: :date,
          nullable: true,
          description: 'Date after which the phase becomes locked and no longer editable (YYYY-MM-DD format). After this date, administrators cannot modify phase settings or content, ensuring data integrity for completed phases. Useful for preserving historical records of participation processes. If null, the phase remains editable indefinitely.'
        },
        phase_tab_name: {
          type: :string,
          nullable: true,
          description: 'The display name of the phase shown in the frontend interface navigation tabs and phase listings. This is a translatable field - provide translations via translations_attributes for multilingual support. If null, defaults to a name derived from the phase type. Examples: "Discussion", "Proposals", "Voting", "Budget Planning".'
        },
        registered_address_grouping_restriction: {
          type: :boolean,
          nullable: true,
          description: 'Whether participation is restricted based on registered address grouping (e.g., district, neighborhood, street). When true, only users whose registered address matches the criteria in registered_address_grouping_restrictions can participate. When false or null, address grouping is not used as a restriction. Useful for hyper-local participation initiatives.'
        },
        registered_address_grouping_restrictions: {
          type: :object,
          nullable: true,
          description: 'Detailed restrictions by registered address grouping as key-value pairs. Key is the grouping type (e.g., "district", "neighborhood", "street"), value is an array of allowed grouping values (e.g., ["District A", "District B"]). Only users whose registered address matches at least one value in each specified grouping can participate. Example: { "district": ["North", "South"], "neighborhood": ["Downtown"] }.',
          additionalProperties: { type: :array, items: { type: :string } }
        },
        individual_group_value_ids: {
          type: :array,
          items: { type: :integer },
          description: 'Array of individual group/demographic value IDs that are allowed to participate in this phase. Individual groups represent demographic segments (e.g., "seniors", "students", "business owners") defined in the system. Only users belonging to at least one of these groups can participate. Empty array means no demographic restriction. Used for targeted engagement campaigns.'
        },
        geozone_restriction_ids: {
          type: :array,
          items: { type: :integer },
          description: 'Array of geographic zone IDs where participation is allowed. Only users whose registered address is in one of these geozones can participate. Requires geozone_restricted to be true. Geozones represent administrative boundaries (districts, neighborhoods, etc.). Empty array with geozone_restricted=true means no one can participate. Used for location-based participation initiatives.'
        },
        settings_attributes: {
          type: :array,
          description: 'Configuration settings for the phase as an array of setting objects. Settings control phase-specific behaviors and features (e.g., comment sorting, moderation rules, display options). Each setting has a key (identifier) and value (configuration). Common keys: "feature.general.newest_first" (sort comments by newest), "moderation.enabled" (enable moderation), etc. Provide id when updating existing settings, omit for new settings.',
          items: {
            type: :object,
            properties: {
              id: {
                type: :integer,
                nullable: true,
                description: 'ID of the setting when updating an existing setting. Omit this field when creating a new setting. Required when modifying or deleting existing settings.'
              },
              key: {
                type: :string,
                nullable: true,
                description: 'Setting identifier/key that determines which feature or behavior is being configured. Format is typically dot-separated (e.g., "feature.general.newest_first", "moderation.enabled"). Must match a valid setting key for the phase type.'
              },
              value: {
                type: :string,
                nullable: true,
                description: 'The setting value/configuration. Common values: "active", "inactive", "true", "false", or other configuration strings depending on the setting key. Some settings accept numeric or JSON values. Null values may remove the setting depending on context.'
              },
              _destroy: {
                type: :boolean,
                nullable: true,
                description: 'Set to true to delete this setting during update. The setting will be removed from the phase configuration. Only applicable when updating existing settings (id must be provided).'
              }
            }
          }
        }
      }
    }.freeze

    # ProjektPhaseSetting schema definition for OpenAPI/Swagger documentation
    PROJEKT_PHASE_SETTING_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the phase setting', example: 1 },
        key: { type: :string, description: 'Setting identifier that determines which feature or behavior is being configured', example: 'feature.general.newest_first' },
        value: { type: :string, nullable: true, description: 'The setting value (e.g., "active", "inactive", or other configuration values)', example: 'active' }
      },
      required: %w[id key]
    }.freeze

    # Poll schema definition for OpenAPI/Swagger documentation
    POLL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the poll', example: 1 },
        name: { type: :string, description: 'The name or title of the poll', example: 'Community Vote' },
        summary: { type: :string, nullable: true, description: 'A brief summary of the poll topic or purpose', example: 'Summary' },
        description: { type: :string, nullable: true, description: 'Detailed description of the poll and its context', example: 'Description' },
        starts_at: { type: :string, format: :date_time, nullable: true, description: 'When the poll opens for voting. Null means no start time restriction.', example: '2025-01-01T00:00:00Z' },
        ends_at: { type: :string, format: :date_time, nullable: true, description: 'When the poll closes. Null means the poll never automatically closes.', example: '2025-01-31T23:59:59Z' },
        geozone_restricted: { type: :boolean, nullable: true, description: 'Whether voting in this poll is restricted to specific geographic zones', example: false },
        budget_id: { type: :integer, nullable: true, description: 'ID of an associated budget if this poll is part of participatory budgeting. Null if not associated with a budget.', example: 1 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the poll was created', example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the poll was last modified', example: '2025-01-01T00:00:00Z' },
        geozones: {
          type: :array,
          description: 'List of geographic zones where this poll is available (only present if geozone_restricted is true)',
          items: {
            type: :object,
            properties: {
              id: { type: :integer, description: 'Geographic zone identifier' },
              name: { type: :string, description: 'Geographic zone name' }
            }
          }
        },
        budget: {
          type: :object,
          nullable: true,
          description: 'Associated budget information if this poll is part of participatory budgeting',
          properties: {
            id: { type: :integer, description: 'Budget identifier' },
            name: { type: :string, description: 'Budget name' }
          }
        },
        questions: {
          type: :array,
          description: 'Array of questions included in this poll for voters to answer',
          items: {
            type: :object,
            properties: {
              id: { type: :integer, description: 'Question identifier' },
              title: { type: :string, description: 'Question text or title' },
              created_at: { type: :string, format: :date_time, description: 'Timestamp when the question was created' },
              updated_at: { type: :string, format: :date_time, description: 'Timestamp when the question was last modified' },
              answers: {
                type: :array,
                description: 'Array of answer options for this question',
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, description: 'Answer option identifier' },
                    title: { type: :string, description: 'Answer option text' },
                    description: { type: :string, nullable: true, description: 'Detailed description of the answer option' },
                    given_order: { type: :integer, description: 'Order position of this answer among other answers' },
                    total_votes: { type: :integer, description: 'Total number of votes for this answer option' },
                    total_votes_percentage: { type: :number, format: :float, description: 'Percentage of total votes this answer received (0-100)' },
                    created_at: { type: :string, format: :date_time, description: 'Timestamp when the answer option was created' },
                    updated_at: { type: :string, format: :date_time, description: 'Timestamp when the answer option was last modified' }
                  }
                }
              }
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
        id: { type: :integer, description: 'Unique identifier for the event', example: 1 },
        title: { type: :string, description: 'The name or title of the event', example: 'Town Hall' },
        description: { type: :string, nullable: true, description: 'Detailed description of the event, its purpose, and agenda', example: 'Discussion on city planning' },
        datetime: { type: :string, format: :date_time, nullable: true, description: 'When the event starts. Null means no specific start time is set.', example: '2025-02-01T18:00:00Z' },
        end_datetime: { type: :string, format: :date_time, nullable: true, description: 'When the event ends. Null means no specific end time is set.', example: '2025-02-01T20:00:00Z' },
        summary: { type: :string, nullable: true, description: 'Short summary or teaser shown in listings', example: 'Quarterly city planning meeting' },
        location: { type: :string, nullable: true, description: 'Physical location or venue where the event takes place. Null for virtual-only events.', example: 'City Hall' },
        weblink: { type: :string, nullable: true, description: 'URL for event registration, livestream, or further information. Null if no link is provided.', example: 'https://example.com/register' },
        open_ended: { type: :boolean, nullable: true, description: 'Whether the event has no fixed end time', example: false },
        language: { type: :string, nullable: true, description: 'Primary language of the event (e.g., "de", "en")', example: 'de' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this event is associated with', example: 10 },
        accessibility: {
          type: :object,
          description: 'Accessibility features available at the event',
          properties: {
            wheelchair_accessible: { type: :boolean, nullable: true },
            accessible_toilet: { type: :boolean, nullable: true },
            disabled_parking_nearby: { type: :boolean, nullable: true },
            tactile_guidance_systems: { type: :boolean, nullable: true },
            induction_loop_available: { type: :boolean, nullable: true },
            assistance_dogs_welcome: { type: :boolean, nullable: true },
            sign_language_interpreter: { type: :boolean, nullable: true }
          }
        },
        projekt_phase: {
          type: :object,
          description: 'Summary of the projekt phase this event belongs to (present when the phase is loaded)',
          properties: {
            id: { type: :integer, example: 10 },
            title: { type: :string, nullable: true, example: 'Events Phase' },
            type: { type: :string, example: 'ProjektPhase::EventPhase' },
            projekt_id: { type: :integer, example: 2 }
          }
        },
        projekt: {
          type: :object,
          description: 'Summary of the projekt this event belongs to (present when the projekt is loaded)',
          properties: {
            id: { type: :integer, example: 2 },
            title: { type: :string, example: 'Community Survey' }
          }
        },
        image: {
          type: :object,
          nullable: true,
          description: 'Associated image, present only when the event has an attached image'
        },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the event was created', example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the event was last modified', example: '2025-01-01T00:00:00Z' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    # ProjektNotification schema definition
    PROJEKT_NOTIFICATION_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the notification', example: 1 },
        title: { type: :string, description: 'The notification headline or subject line', example: 'Update' },
        body: { type: :string, nullable: true, description: 'The full text content of the notification message', example: 'We have news' },
        link_text: { type: :string, nullable: true, description: 'The text displayed for a clickable link (e.g., "Read more", "Learn more")', example: 'Read more' },
        link_url: { type: :string, nullable: true, description: 'The URL that the link_text directs to when clicked', example: 'https://example.com' },
        segment_recipient: { type: :string, nullable: true, description: 'The audience segment for this notification (e.g., "all", specific user groups)', example: 'all' },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this notification is associated with', example: 10 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the notification was created', example: '2025-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the notification was last modified', example: '2025-01-01T00:00:00Z' }
      },
      required: %w[id title created_at updated_at]
    }.freeze

    # ContentBlock schema definition for OpenAPI/Swagger documentation
    CONTENT_BLOCK_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the content block', example: 1 },
        title: { type: :string, nullable: true, description: 'Optional heading or title for the content block', example: 'Introduction' },
        body: { type: :string, nullable: true, description: 'The main text content of the block (supports HTML/rich text)', example: 'This is the content of the block.' },
        locale: { type: :string, description: 'Language code for this content block (e.g., "en" for English, "de" for German)', example: 'en' },
        position: { type: :integer, description: 'The display order of this block. Lower numbers appear first.', example: 0 },
        blockable_type: { type: :string, description: 'The type of resource this block belongs to (e.g., "Projekt", "Page")', example: 'Projekt' },
        blockable_id: { type: :integer, description: 'The ID of the resource this block belongs to', example: 1 },
        created_at: { type: :string, format: :datetime, description: 'Timestamp when the content block was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :datetime, description: 'Timestamp when the content block was last modified', example: '2024-01-01T00:00:00Z' }
      },
      required: %w[id position blockable_type blockable_id]
    }.freeze

    # All schemas combined for easy reference in swagger_helper
    def self.all
      {
        Projekt: PROJEKT_SCHEMA,
        Image: IMAGE_SCHEMA,
        ImageAttributesApi: IMAGE_ATTRIBUTES_API_SCHEMA,
        ProjektImageUpdateParams: PROJEKT_IMAGE_UPDATE_PARAMS,
        ProjektCreateParams: PROJEKT_CREATE_PARAMS,
        ProjektUpdateParams: PROJEKT_UPDATE_PARAMS,
        ProjektPhase: PROJEKT_PHASE_SCHEMA,
        ProjektPhaseRequestParams: PROJEKT_PHASE_REQUEST_SCHEMA,
        ContentBlock: CONTENT_BLOCK_SCHEMA,
        ProjektPhaseSetting: PROJEKT_PHASE_SETTING_SCHEMA,
        Poll: POLL_SCHEMA,
        ProjektEvent: PROJEKT_EVENT_SCHEMA,
        ProjektNotification: PROJEKT_NOTIFICATION_SCHEMA
      }
    end
  end
end

