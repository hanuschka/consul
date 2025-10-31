# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Arguments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/projekt_arguments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (ArgumentPhase)'

    post 'Create a projekt argument' do
      tags 'Projekt Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_argument, in: :body, description: 'Projekt argument creation payload', schema: {
        type: :object,
        properties: {
          projekt_argument: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              position: { type: :integer, nullable: true },
              note: { type: :string, nullable: true },
              pro: { type: :boolean, nullable: true },
              image_attributes: {
                type: :object,
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image' },
                  title: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                }
              }
            }
          }
        },
        required: ['projekt_argument']
      }

      response '201', 'projekt argument created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Test Argument',
              position: 1,
              note: 'Test note',
              pro: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektArgument).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
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

  path '/api/projekt_arguments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Argument ID'

    get 'Retrieve a projekt argument' do
      tags 'Projekt Arguments'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt argument found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Test Argument',
            position: 1,
            note: 'Test note',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a projekt argument' do
      tags 'Projekt Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_argument, in: :body, description: 'Attributes to update on the projekt argument', schema: {
        type: :object,
        properties: {
          projekt_argument: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              position: { type: :integer, nullable: true },
              note: { type: :string, nullable: true },
              pro: { type: :boolean, nullable: true },
              image_attributes: {
                type: :object,
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image' },
                  title: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                }
              }
            }
          }
        },
        required: ['projekt_argument']
      }

      response '200', 'projekt argument updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:test_projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Original Argument',
            position: 1,
            note: 'Original note',
            pro: true
          )
        end
        let(:id) { test_projekt_argument.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Updated Argument',
              note: 'Updated note'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Updated Argument'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:test_projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Original Argument',
            position: 1,
            pro: true
          )
        end
        let(:id) { test_projekt_argument.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektArgument).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
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

    delete 'Delete a projekt argument' do
      tags 'Projekt Arguments'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt argument deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Argument To Delete',
            position: 1,
            note: 'Note to delete',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt argument' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Argument',
            position: 1,
            note: 'Test note',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

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
          allow_any_instance_of(ProjektArgument).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt argument'] })
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end
