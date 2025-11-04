# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'ProjektIframes API', type: :request do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_iframes/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Phase (IframePhase) ID'

    get 'Retrieve a projekt iframe' do
      tags 'ProjektIframes'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt iframe found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_iframe: { type: :object }
                   },
                   required: ['projekt_iframe']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:id) { test_iframe_phase.id }

        run_test!
      end

      response '404', 'projekt iframe not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:id) { test_iframe_phase.id }

        before do
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    patch 'Update a projekt iframe' do
      tags 'ProjektIframes'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_iframe, in: :body, description: 'Attributes to update on the projekt iframe', schema: {
        type: :object,
        properties: {
          projekt_iframe: {
            type: :object,
            properties: {
              iframe_url: { type: :string },
              iframe_height: { type: :string }
            }
          }
        }
      }

      response '200', 'projekt iframe updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              iframe_url: 'https://example.com/iframe',
              iframe_height: '600px'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_iframe: { type: :object }
                   },
                   required: ['projekt_iframe']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt iframe not found' do
        let(:id) { 999999 }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              iframe_url: 'https://example.com/iframe'
            }
          }
        end

        run_test!
      end

      response '200', 'projekt iframe updated with partial data' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              iframe_url: 'https://example.com/iframe'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_iframe: { type: :object }
                   },
                   required: ['projekt_iframe']
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
        let(:id) { test_iframe_phase.id }
        let(:projekt_iframe) do
          {
            projekt_iframe: {
              iframe_url: 'https://example.com/iframe',
              iframe_height: '600px'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
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
