# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Phases API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekts/{projekt_id}/projekt_phases' do
    parameter name: :projekt_id, in: :path, type: :integer, description: 'Projekt ID'

    get 'List projekt phases for a projekt' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all phases defined for a specific projekt. Phases define different stages of participation (comments, proposals, voting, budgeting, etc.) with their own active/inactive periods, visibility settings, and restrictions. Returns full details including phase type, dates, and configuration. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt phases found and returned (admin sees all)' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Phases') }
        let(:projekt_id) { projekt.id }

        before do
          projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, frontend_visibility: true, phase_tab_name: 'Comments')
          projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: false, frontend_visibility: false, phase_tab_name: 'Questions')
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
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   },
                   required: ['current_page', 'total_pages', 'total_count', 'per_page']
                 }
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['projekt_phases'].length).to eq(2)
        end
      end

      response '200', 'projekt phases found and returned (public_data sees only visible/active)' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Phases') }
        let(:projekt_id) { projekt.id }

        before do
          api_client.update!(access_level: :public_data)
          projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, frontend_visibility: true, phase_tab_name: 'Comments')
          projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: false, frontend_visibility: false, phase_tab_name: 'Questions')
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
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   },
                   required: ['current_page', 'total_pages', 'total_count', 'per_page']
                 }
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['projekt_phases'].length).to eq(1)
          expect(data['data']['projekt_phases'][0]['phase_tab_name']).to eq('Comments')
        end
      end

      unauthorized_response { let(:projekt_id) { 1 } }
    end

    post 'Create a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new phase for a projekt. Phases are time-bounded periods that enable specific types of participation (comments, proposals, voting, etc.). Supports restrictions by geozone, age range, user status, and demographic groups. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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
                description: 'Phase type determining participation type. Required for creation.'
              },
              start_date: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date when the phase becomes active (YYYY-MM-DD). Must be before end_date if both provided.'
              },
              end_date: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date when the phase becomes inactive (YYYY-MM-DD). Must be after start_date if both provided.'
              },
              active: {
                type: :boolean,
                description: 'Whether the phase is currently active and allowing participation.'
              },
              frontend_visibility: {
                type: :boolean,
                description: 'Whether the phase is visible to users on the frontend interface.'
              },
              given_order: {
                type: :integer,
                nullable: true,
                description: 'Display order of this phase. Lower numbers appear first.'
              },
              geozone_restricted: {
                type: :boolean,
                description: 'Whether participation is restricted to specific geographic zones.'
              },
              age_range_id: {
                type: :integer,
                nullable: true,
                description: 'ID of an age range restriction. If null, there is no age restriction.'
              },
              user_status: {
                type: :string,
                nullable: true,
                description: 'Minimum user status required. Valid values: "guest", "registered", "verified".'
              },
              lock_on: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date after which the phase becomes locked and no longer editable (YYYY-MM-DD).'
              },
              phase_tab_name: {
                type: :string,
                nullable: true,
                description: 'Display name shown in frontend navigation tabs and phase listings.'
              },
              registered_address_grouping_restriction: {
                type: :boolean,
                nullable: true,
                description: 'Whether participation is restricted based on registered address grouping.'
              },
              registered_address_grouping_restrictions: {
                type: :object,
                nullable: true,
                description: 'Restrictions by address grouping as key-value pairs. Example: { "district": ["North", "South"] }.',
                additionalProperties: { type: :array, items: { type: :string } }
              },
              individual_group_value_ids: {
                type: :array,
                items: { type: :integer },
                description: 'Array of demographic group IDs allowed to participate.'
              },
              geozone_restriction_ids: {
                type: :array,
                items: { type: :integer },
                description: 'Array of geographic zone IDs where participation is allowed. Requires geozone_restricted to be true.'
              },
              settings_attributes: {
                type: :array,
                description: 'Configuration settings for the phase. Provide id when updating existing settings.',
                items: {
                  type: :object,
                  properties: {
                    id: {
                      type: :integer,
                      nullable: true,
                      description: 'ID of the setting when updating. Omit when creating new.'
                    },
                    key: {
                      type: :string,
                      nullable: true,
                      description: 'Setting identifier/key (e.g., "feature.general.newest_first").'
                    },
                    value: {
                      type: :string,
                      nullable: true,
                      description: 'Setting value (e.g., "active", "inactive", "true", "false").'
                    },
                    _destroy: {
                      type: :boolean,
                      nullable: true,
                      description: 'Set to true to delete this setting during update.'
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

      unauthorized_response { let(:projekt_id) { 1 } }
      forbidden_response { let(:projekt_id) { 1 } }
    end
  end

  path '/api/projekt_phases/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update a projekt phase setting by key' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update or create a configuration setting for a projekt phase. Settings control behavior and features for the phase (e.g., feature.general.newest_first controls comment sorting). Returns the updated setting. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end

  path '/api/projekt_phases/{id}/update_settings' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update multiple projekt phase settings' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Bulk-update several projekt phase settings in a single request. Provide a settings object mapping each setting key to its new value; missing keys are created. Returns the list of updated keys and a per-key errors map for any that failed. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :settings, in: :body, description: 'Object whose keys are projekt phase setting keys and whose values are the new setting values', schema: {
        type: :object,
        properties: {
          settings: {
            type: :object,
            description: 'Map of setting key => value (e.g. feature.general.newest_first).',
            additionalProperties: { type: :string },
            example: { 'feature.general.newest_first' => 'active' }
          }
        },
        required: ['settings']
      }

      response '200', 'settings processed' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Settings Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:settings) do
          { settings: { 'feature.general.newest_first' => 'active' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     updated: { type: :array, items: { type: :string } },
                     errors: { type: :object }
                   },
                   required: %w[updated errors]
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'settings parameter missing' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Settings Update') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:id) { phase.id }
        let(:settings) { {} }

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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end

  path '/api/projekt_phases/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'Retrieve a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single projekt phase by ID with all its configuration details. Returns the phase type, active status, dates, visibility settings, restrictions (geozone, age range, user status), and all settings. #{ApiAccessRequirements::GET_READ_ONLY}"

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

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt phase' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt phase configuration. All fields are optional - only provide fields to change. Supports updating type, dates, visibility, restrictions, settings, and more. Returns the updated phase. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_phase, in: :body, description: 'Phase attributes to update - all optional (type, dates, active status, visibility, restrictions, settings, etc.)', schema: {
        type: :object,
        properties: {
          projekt_phase: {
            type: :object,
            properties: {
              type: {
                type: :string,
                enum: ProjektPhase::PROJEKT_PHASES_TYPES,
                description: 'Phase type determining participation type.'
              },
              start_date: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date when the phase becomes active (YYYY-MM-DD). Must be before end_date if both provided.'
              },
              end_date: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date when the phase becomes inactive (YYYY-MM-DD). Must be after start_date if both provided.'
              },
              active: {
                type: :boolean,
                nullable: true,
                description: 'Whether the phase is currently active and allowing participation.'
              },
              frontend_visibility: {
                type: :boolean,
                nullable: true,
                description: 'Whether the phase is visible to users on the frontend interface.'
              },
              given_order: {
                type: :integer,
                nullable: true,
                description: 'Display order of this phase. Lower numbers appear first.'
              },
              geozone_restricted: {
                type: :boolean,
                nullable: true,
                description: 'Whether participation is restricted to specific geographic zones.'
              },
              age_range_id: {
                type: :integer,
                nullable: true,
                description: 'ID of an age range restriction. If null, there is no age restriction.'
              },
              user_status: {
                type: :string,
                nullable: true,
                description: 'Minimum user status required. Valid values: "guest", "registered", "verified".'
              },
              lock_on: {
                type: :string,
                format: :date,
                nullable: true,
                description: 'Date after which the phase becomes locked and no longer editable (YYYY-MM-DD).'
              },
              phase_tab_name: {
                type: :string,
                nullable: true,
                description: 'Display name shown in frontend navigation tabs and phase listings.'
              },
              registered_address_grouping_restriction: {
                type: :boolean,
                nullable: true,
                description: 'Whether participation is restricted based on registered address grouping.'
              },
              registered_address_grouping_restrictions: {
                type: :object,
                nullable: true,
                description: 'Restrictions by address grouping as key-value pairs. Example: { "district": ["North", "South"] }.',
                additionalProperties: { type: :array, items: { type: :string } }
              },
              individual_group_value_ids: {
                type: :array,
                items: { type: :integer },
                nullable: true,
                description: 'Array of demographic group IDs allowed to participate.'
              },
              geozone_restriction_ids: {
                type: :array,
                items: { type: :integer },
                nullable: true,
                description: 'Array of geographic zone IDs where participation is allowed. Requires geozone_restricted to be true.'
              },
              settings_attributes: {
                type: :array,
                nullable: true,
                description: 'Configuration settings for the phase. Provide id when updating existing settings.',
                items: {
                  type: :object,
                  properties: {
                    id: {
                      type: :integer,
                      nullable: true,
                      description: 'ID of the setting when updating. Omit when creating new.'
                    },
                    key: {
                      type: :string,
                      nullable: true,
                      description: 'Setting identifier/key (e.g., "feature.general.newest_first").'
                    },
                    value: {
                      type: :string,
                      nullable: true,
                      description: 'Setting value (e.g., "active", "inactive", "true", "false").'
                    },
                    _destroy: {
                      type: :boolean,
                      nullable: true,
                      description: 'Set to true to delete this setting during update.'
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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end

    delete 'Delete a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt phase and all associated data. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end
end


