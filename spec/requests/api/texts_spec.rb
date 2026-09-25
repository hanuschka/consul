# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Texts API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/texts' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LegislationPhase)'

    get 'List all texts' do
      tags 'Texts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all texts/legislation documents for a projekt phase. Texts support multi-phase review processes: draft publication, debate period, and allegations/amendments period.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

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
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end
end
