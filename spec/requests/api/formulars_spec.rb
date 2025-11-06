# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Formulars API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/formulars' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    post 'Create a formular' do
      tags 'Formulars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Create a new custom form for a projekt phase. Forms collect structured input from participants using customizable fields and validation rules. Required: form title and field definitions. Requires admin access.'

      parameter name: :formular, in: :body, description: 'Formular (form) creation with required title and form field configuration', schema: {
        type: :object,
        properties: {
          formular: {
            type: :object,
            properties: {}
          }
        },
        required: ['formular']
      }

      response '201', 'formular created' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::FormularPhase.create!(projekt: test_projekt).id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: { type: :object }
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::FormularPhase.create!(projekt: test_projekt).id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        before do
          allow_any_instance_of(Formular).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Invalid formular'])
          allow_any_instance_of(Formular).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::FormularPhase.create!(projekt: test_projekt).id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end
  end

  path '/api/formulars/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Formular ID'

    get 'Retrieve a formular' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'formular found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: { type: :object }
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        run_test!
      end

      response '404', 'formular not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        before do
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    patch 'Update a formular' do
      tags 'Formulars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :formular, in: :body, description: 'Attributes to update on the formular', schema: {
        type: :object,
        properties: {
          formular: {
            type: :object,
            properties: {}
          }
        },
        required: ['formular']
      }

      response '200', 'formular updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: { type: :object }
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'formular not found' do
        let(:id) { 999999 }
        let(:formular) do
          {
            formular: {}
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        before do
          allow_any_instance_of(Formular).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Update failed'])
          allow_any_instance_of(Formular).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }
        let(:formular) do
          {
            formular: {}
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    delete 'Delete a formular' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'formular deleted' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'formular not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete formular' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

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
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete formular'] })

          allow_any_instance_of(Formular).to receive(:destroy).and_return(false)
          allow_any_instance_of(Formular).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end
  end
end
