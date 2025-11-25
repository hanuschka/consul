# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestones API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an access_token
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/milestones' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List all milestones' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all milestones for a projekt phase. Milestones track project progress over time and include status updates. Each milestone spans a date range and contains status information about completed activities.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of milestones per page (default: 100, max: 500)'

      response '200', 'milestones found and returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestones: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['milestones']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

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
