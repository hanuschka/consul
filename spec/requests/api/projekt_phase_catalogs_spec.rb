# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Phase Catalogs API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }
  let(:proposal_phase) { create_projekt_phase('ProjektPhase::ProposalPhase') }

  path '/api/projekt_phases/{projekt_phase_id}/projekt_labels' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt phase ID'

    get 'List the labels of a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Labels contributions of the phase can carry. Use their ids in projekt_label_ids when writing proposals or budget investments. Clients with public_data access only get labels of phases shown to visitors.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'labels found' do
        let(:projekt_phase_id) { proposal_phase.id }

        before do
          Globalize.with_locale(:de) do
            ProjektLabel.create!(projekt_phase: proposal_phase, name: 'Verkehr', color: '#e65100', icon: 'bicycle')
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_labels: { type: :array, items: { '$ref' => '#/components/schemas/ProjektLabel' } }
                   },
                   required: ['projekt_labels']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          label_data = JSON.parse(response.body)['data']['projekt_labels'].first

          expect(label_data['color']).to eq('#e65100')
          expect(label_data['icon']).to eq('bicycle')
          expect(label_data['translations']['de']['name']).to eq('Verkehr')
        end
      end

      response '403', 'phase hidden from public_data clients' do
        let(:projekt_phase_id) { proposal_phase.id }

        before do
          api_client.update!(access_level: :public_data)
          proposal_phase.update!(frontend_visibility: false)
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { proposal_phase.id } }
    end
  end

  path '/api/projekt_phases/{projekt_phase_id}/sentiments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt phase ID'

    get 'List the sentiments of a projekt phase' do
      tags 'Projekt Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Sentiments contributions of the phase can carry. Use their ids in sentiment_id when writing proposals or budget investments. Clients with public_data access only get sentiments of phases shown to visitors.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'sentiments found' do
        let(:projekt_phase_id) { proposal_phase.id }

        before do
          Globalize.with_locale(:de) do
            Sentiment.create!(projekt_phase: proposal_phase, name: 'Zustimmung', color: '#2e7d32')
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     sentiments: { type: :array, items: { '$ref' => '#/components/schemas/Sentiment' } }
                   },
                   required: ['sentiments']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          sentiment_data = JSON.parse(response.body)['data']['sentiments'].first

          expect(sentiment_data['color']).to eq('#2e7d32')
          expect(sentiment_data['translations']['de']['name']).to eq('Zustimmung')
        end
      end

      response '403', 'phase hidden from public_data clients' do
        let(:projekt_phase_id) { proposal_phase.id }

        before do
          api_client.update!(access_level: :public_data)
          proposal_phase.update!(active: false)
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { proposal_phase.id } }
    end
  end
end
