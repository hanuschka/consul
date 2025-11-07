# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Texts API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/texts' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LegislationPhase)'

    get 'List all texts' do
      tags 'Texts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all texts/legislation documents for a projekt phase. Texts support multi-phase review processes: draft publication, debate period, and allegations/amendments period.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of texts per page (default: 100, max: 500)'

      response '200', 'texts found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     texts: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['texts']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   }
                 }
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }

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
  end
end
