# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Phases API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekts/{projekt_id}/projekt_phases' do
    parameter name: :projekt_id, in: :path, type: :integer, description: 'Projekt ID'

    get 'List projekt phases for a projekt' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retrieve all phases defined for a specific projekt. Phases define different stages of participation (comments, proposals, voting, budgeting, etc.) with their own active/inactive periods, visibility settings, and restrictions. Returns full details including phase type, dates, and configuration.'

      response '200', 'projekt phases found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Phases') }
        let(:projekt_id) { projekt.id }

        before do
          projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments')
          projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: false, phase_tab_name: 'Questions')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phases: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektPhase' }
                     }
                   },
                   required: ['projekt_phases']
                 }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Create a new phase for a projekt. Phases are time-bounded periods that enable specific types of participation (comments, proposals, voting, etc.). Requires admin access. Supports restrictions by geozone, age range, user status, and demographic groups.'

      parameter name: :projekt_phase, in: :body, description: 'Phase configuration with required type and optional start/end dates, visibility, restrictions, and settings', schema: {
        type: :object,
        properties: {
          projekt_phase: {
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
            },
            required: ['type']
          }
        },
        required: ['projekt_phase']
      }

      response '201', 'projekt phase created' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: 'ProjektPhase::CommentPhase',
              active: true,
              frontend_visibility: true,
              phase_tab_name: 'Discussion'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid projekt phase type' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: 'InvalidPhaseType',
              active: true,
              frontend_visibility: true
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end

      response '422', 'missing required type field' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              active: true,
              frontend_visibility: true
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end
  end

  path '/api/projekt_phases/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update a projekt phase setting by key' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Update or create a configuration setting for a projekt phase. Settings control behavior and features for the phase (e.g., feature.general.newest_first controls comment sorting). Requires admin access. Returns the updated setting.'

      parameter name: :projekt_phase_setting, in: :body, description: 'Setting with required key and optional value to update or create', schema: {
        type: :object,
        properties: {
          projekt_phase_setting: {
            type: :object,
            properties: {
              key: { type: :string },
              value: { type: :string, nullable: true }
            },
            required: ['key']
          }
        },
        required: ['projekt_phase_setting']
      }

      response '200', 'projekt phase setting updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { key: 'feature.general.newest_first', value: 'active' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase_setting: { '$ref' => '#/components/schemas/ProjektPhaseSetting' }
                   },
                   required: ['projekt_phase_setting']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Setting Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:projekt_phase_setting) do
          { projekt_phase_setting: { value: 'active' } }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end
  end
  path '/api/projekt_phases/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'Retrieve a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retrieve a single projekt phase by ID with all its configuration details. Returns the phase type, active status, dates, visibility settings, restrictions (geozone, age range, user status), and all settings.'

      response '200', 'projekt phase found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Show') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt phase not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Update an existing projekt phase configuration. All fields are optional - only provide fields to change. Supports updating type, dates, visibility, restrictions, settings, and more. Requires admin access. Returns the updated phase.'

      parameter name: :projekt_phase, in: :body, description: 'Phase attributes to update - all optional (type, dates, active status, visibility, restrictions, settings, etc.)', schema: {
        type: :object,
        properties: {
          projekt_phase: {
            type: :object,
            properties: {
              type: {
                type: :string,
                enum: ProjektPhase::PROJEKT_PHASES_TYPES,
                description: 'The type of projekt phase that determines what kind of participation or content is available. Regular phases: CommentPhase (discussion/feedback), ProposalPhase (citizen proposals), QuestionPhase (Q&A), VotingPhase (polls/voting), BudgetPhase (participatory budgeting), LegislationPhase (legislative process), FormularPhase (forms/surveys). Special phases: LivestreamPhase (live streaming), MilestonePhase (timeline milestones), ProjektNotificationPhase (announcements), EventPhase (events/meetings), ArgumentPhase (pro/con arguments), NewsfeedPhase (news feed), IframePhase (embedded content), PointOfInterestPhase (map pins).'
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
                nullable: true,
                description: 'Whether the phase is currently active and allowing participation. When true, users can interact with the phase (submit comments, proposals, vote, etc.) based on other restrictions. When false, the phase is inactive regardless of date settings.'
              },
              frontend_visibility: {
                type: :boolean,
                nullable: true,
                description: 'Whether the phase is visible to users on the frontend interface. When true, the phase appears in navigation tabs and phase listings. When false, the phase is hidden from public view but may still be accessible via direct links or admin interfaces.'
              },
              given_order: {
                type: :integer,
                nullable: true,
                description: 'The display order/position of this phase among other phases in the projekt. Lower numbers appear first in phase navigation and listings. If null, phases are ordered by creation date.'
              },
              geozone_restricted: {
                type: :boolean,
                nullable: true,
                description: 'Whether participation in this phase is restricted to specific geographic zones. When true, only users from geozones listed in geozone_restriction_ids can participate. When false, all users can participate (subject to other restrictions).'
              },
              age_range_id: {
                type: :integer,
                nullable: true,
                description: 'ID of an age range restriction that limits participation to users within a specific age group. If null, there is no age restriction. Age ranges are predefined categories (e.g., "18-25", "26-35", "65+") used to ensure age-appropriate participation or comply with legal requirements.'
              },
              user_status: {
                type: :string,
                nullable: true,
                description: 'Minimum user status required to participate in this phase. Valid values: "guest" (anyone, including anonymous), "registered" (must be logged in), "verified" (must have verified account). Higher verification levels ensure more trusted participation but may reduce engagement.'
              },
              lock_on: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date after which the phase becomes locked and no longer editable (YYYY-MM-DD format). After this date, administrators cannot modify phase settings or content, ensuring data integrity for completed phases.'
              },
              phase_tab_name: {
                type: :string,
                nullable: true,
                description: 'The display name of the phase shown in the frontend interface navigation tabs and phase listings. This is a translatable field - provide translations via translations_attributes for multilingual support. Examples: "Discussion", "Proposals", "Voting", "Budget Planning".'
              },
              registered_address_grouping_restriction: {
                type: :boolean,
                nullable: true,
                description: 'Whether participation is restricted based on registered address grouping (e.g., district, neighborhood, street). When true, only users whose registered address matches the criteria in registered_address_grouping_restrictions can participate.'
              },
              registered_address_grouping_restrictions: {
                type: :object,
                nullable: true,
                description: 'Detailed restrictions by registered address grouping as key-value pairs. Key is the grouping type (e.g., "district", "neighborhood", "street"), value is an array of allowed grouping values. Example: { "district": ["North", "South"], "neighborhood": ["Downtown"] }.',
                additionalProperties: { type: :array, items: { type: :string } }
              },
              individual_group_value_ids: {
                type: :array,
                items: { type: :integer },
                nullable: true,
                description: 'Array of individual group/demographic value IDs that are allowed to participate in this phase. Individual groups represent demographic segments (e.g., "seniors", "students", "business owners") defined in the system.'
              },
              geozone_restriction_ids: {
                type: :array,
                items: { type: :integer },
                nullable: true,
                description: 'Array of geographic zone IDs where participation is allowed. Only users whose registered address is in one of these geozones can participate. Requires geozone_restricted to be true.'
              },
              settings_attributes: {
                type: :array,
                nullable: true,
                description: 'Configuration settings for the phase as an array of setting objects. Settings control phase-specific behaviors and features (e.g., comment sorting, moderation rules, display options). Common keys: "feature.general.newest_first" (sort comments by newest), "moderation.enabled" (enable moderation).',
                items: {
                  type: :object,
                  properties: {
                    id: {
                      type: :integer,
                      nullable: true,
                      description: 'ID of the setting when updating an existing setting. Omit when creating a new setting.'
                    },
                    key: {
                      type: :string,
                      nullable: true,
                      description: 'Setting identifier/key that determines which feature or behavior is being configured. Format is typically dot-separated (e.g., "feature.general.newest_first").'
                    },
                    value: {
                      type: :string,
                      nullable: true,
                      description: 'The setting value/configuration. Common values: "active", "inactive", "true", "false", or other configuration strings.'
                    },
                    _destroy: {
                      type: :boolean,
                      nullable: true,
                      description: 'Set to true to delete this setting during update. Only applicable when updating existing settings (id must be provided).'
                    }
                  }
                }
              }
            }
          }
        }
      }

      response '200', 'projekt phase updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              active: false,
              phase_tab_name: 'Updated Title'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_phase: { '$ref' => '#/components/schemas/ProjektPhase' }
                   },
                   required: ['projekt_phase']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Update') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments') }
        let(:id) { test_phase.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              start_date: '2030-01-01',
              end_date: '2020-01-01'
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPhase).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['End date must be after start date'])
          allow_any_instance_of(ProjektPhase).to receive(:errors).and_return(errors_mock)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end

    delete 'Delete a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt phase deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Delete') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt phase not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt phase' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Delete') }
        let(:test_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { test_phase.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        before do
          allow_any_instance_of(ProjektPhase).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt phase'] })
          allow_any_instance_of(ProjektPhase).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end


