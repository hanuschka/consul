# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Iframes API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an access_token
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/iframe' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase (IframePhase) ID'

    get 'Retrieve an iframe' do
      tags 'Iframes'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve the iframe of an iframe phase: the URL, width and height the phase page embeds, as set in /adm or through this API.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'iframe found' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }

        before do
          test_iframe_phase.settings
            .find_or_initialize_by(key: 'option.general.iframe_url')
            .update!(value: 'https://example.com/set-in-adm')
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

        run_test! do |response|
          iframe = JSON.parse(response.body)['data']['iframe']

          expect(iframe['url']).to eq('https://example.com/set-in-adm')
        end
      end

      response '404', 'iframe not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    patch 'Update an iframe' do
      tags 'Iframes'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update the iframe of an iframe phase. The values are the ones the phase page embeds and /adm edits. Send only the fields to change; an empty string clears a value. A body without a `projekt_iframe` object returns 400. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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

        run_test! do
          stored_values = test_iframe_phase.settings
            .where(key: %w[option.general.iframe_url option.general.iframe_width option.general.iframe_height])
            .pluck(:key, :value)
            .to_h

          expect(stored_values).to eq(
            'option.general.iframe_url' => 'https://example.com/embed',
            'option.general.iframe_width' => '1200',
            'option.general.iframe_height' => '600'
          )
        end
      end

      response '200', 'iframe values cleared' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }
        let(:projekt_iframe) { { projekt_iframe: { url: '', height: '' } } }

        before do
          test_iframe_phase.settings
            .find_or_initialize_by(key: 'option.general.iframe_url')
            .update!(value: 'https://example.com/embed')
        end

        run_test! do |response|
          iframe = JSON.parse(response.body)['data']['iframe']
          stored_values = test_iframe_phase.settings
            .where(key: %w[option.general.iframe_url option.general.iframe_height])
            .pluck(:value)

          expect(iframe['url']).to eq('')
          expect(iframe['height']).to eq('')
          expect(stored_values).to eq(['', ''])
        end
      end

      response '400', 'projekt_iframe object missing' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:test_iframe_phase) { ProjektPhase::IframePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { test_iframe_phase.id }
        let(:projekt_iframe) { {} }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('bad_request')
        end
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

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end
end
