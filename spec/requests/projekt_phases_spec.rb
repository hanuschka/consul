# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Phases API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekts/{projekt_id}/projekt_phases' do
    parameter name: :projekt_id, in: :path, type: :integer, description: 'Projekt ID'

    get 'List projekt phases for a projekt' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt phases found' do
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

      parameter name: :projekt_phase, in: :body, description: 'Projekt Phase creation payload', schema: {
        type: :object,
        properties: {
          projekt_phase: {
            type: :object,
            properties: {
              type: { type: :string, example: 'ProjektPhase::CommentPhase' },
              start_date: { type: :string, format: :date, nullable: true },
              end_date: { type: :string, format: :date, nullable: true },
              active: { type: :boolean },
              frontend_visibility: { type: :boolean },
              given_order: { type: :integer, nullable: true },
              geozone_restricted: { type: :boolean },
              age_range_id: { type: :integer, nullable: true },
              user_status: { type: :string, nullable: true },
              lock_on: { type: :string, format: :date, nullable: true },
              phase_tab_name: { type: :string, nullable: true, description: 'Translated attribute' },
              registered_address_grouping_restriction: { type: :boolean, nullable: true },
              registered_address_grouping_restrictions: { type: :object, additionalProperties: { type: :array, items: { type: :string } } },
              individual_group_value_ids: { type: :array, items: { type: :integer } },
              geozone_restriction_ids: { type: :array, items: { type: :integer } },
              settings_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    key: { type: :string, nullable: true },
                    value: { type: :string, nullable: true },
                    _destroy: { type: :boolean, nullable: true }
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

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Phase Create') }
        let(:projekt_id) { projekt.id }
        let(:projekt_phase) do
          {
            projekt_phase: {
              type: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPhase).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Type is invalid'])
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
  end

  path '/api/projekt_phases/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase ID'

    patch 'Update a projekt phase setting by key' do
      tags 'Projekt Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_phase_setting, in: :body, description: 'Setting payload', schema: {
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

      response '200', 'projekt phase found' do
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

      parameter name: :projekt_phase, in: :body, description: 'Attributes to update on the projekt phase', schema: {
        type: :object,
        properties: {
          projekt_phase: {
            type: :object,
            properties: {
              type: { type: :string },
              start_date: { type: :string, format: :date, nullable: true },
              end_date: { type: :string, format: :date, nullable: true },
              active: { type: :boolean },
              frontend_visibility: { type: :boolean },
              given_order: { type: :integer, nullable: true },
              geozone_restricted: { type: :boolean },
              age_range_id: { type: :integer, nullable: true },
              user_status: { type: :string, nullable: true },
              lock_on: { type: :string, format: :date, nullable: true },
              phase_tab_name: { type: :string, nullable: true, description: 'Translated attribute' },
              registered_address_grouping_restriction: { type: :boolean, nullable: true },
              registered_address_grouping_restrictions: { type: :object, additionalProperties: { type: :array, items: { type: :string } } },
              individual_group_value_ids: { type: :array, items: { type: :integer } },
              geozone_restriction_ids: { type: :array, items: { type: :integer } },
              settings_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    key: { type: :string, nullable: true },
                    value: { type: :string, nullable: true },
                    _destroy: { type: :boolean, nullable: true }
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


