# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Iframes API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/iframe' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase (IframePhase) ID'

    get 'Retrieve an iframe' do
      tags 'Iframes'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'iframe found' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     iframe: {
                       type: :object,
                       properties: {
                         projekt_phase: { type: :object },
                         url: { type: :string },
                         width: { type: :string },
                         height: { type: :string }
                       },
                       required: ['projekt_phase']
                     }
                   },
                   required: ['iframe']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'iframe not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }

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

    patch 'Update an iframe' do
      tags 'Iframes'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_iframe, in: :body, description: 'Attributes to update on the iframe', schema: {
        type: :object,
        properties: {
          projekt_iframe: {
            type: :object,
            properties: {
              url: { type: :string },
              width: { type: :string },
              height: { type: :string }
            }
          }
        }
      }

      response '200', 'iframe updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              url: 'https://example.com/embed',
              width: '1200',
              height: '600'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     iframe: {
                       type: :object,
                       properties: {
                         projekt_phase: { type: :object },
                         url: { type: :string },
                         width: { type: :string },
                         height: { type: :string }
                       },
                       required: ['projekt_phase']
                     }
                   },
                   required: ['iframe']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'iframe not found' do
        let(:projekt_phase_id) { 999999 }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              url: 'https://example.com/embed'
            }
          }
        end

        run_test!
      end

      response '200', 'iframe updated with partial data' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              url: 'https://example.com/embed'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     iframe: {
                       type: :object,
                       properties: {
                         projekt_phase: { type: :object },
                         url: { type: :string },
                         width: { type: :string },
                         height: { type: :string }
                       },
                       required: ['projekt_phase']
                     }
                   },
                   required: ['iframe']
                 }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              url: 'https://example.com/embed',
              width: '1200',
              height: '600'
            }
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
end
