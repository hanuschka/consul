# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Masterportal Collections API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }
  let(:pin_phase) { create_projekt_phase('ProjektPhase::PointOfInterestPhase') }
  let!(:masterportal_collection) do
    MasterportalCollection.create!(
      projekt_phase: pin_phase,
      collection_id: 'trinkbrunnen',
      name: 'Trinkbrunnen',
      endpoint_url: 'https://geo.example.org/wfs',
      feature_color: '#0277bd',
      import_status: 'failed',
      import_error: 'timeout'
    )
  end

  path '/api/projekt_phases/{projekt_phase_id}/masterportal_collections' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt phase ID'

    get 'List the Masterportal collections of a projekt phase' do
      tags 'Masterportal'
      produces 'application/json'
      security [bearer_auth: []]
      description "Masterportal layers imported into the phase, ordered by name. Admin clients also receive the GeoServer URL and whether features become contributions. Import state and errors are never returned. Clients with public_data access only get collections of phases shown to visitors.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'collections found' do
        let(:projekt_phase_id) { pin_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     masterportal_collections: { type: :array, items: { '$ref' => '#/components/schemas/MasterportalCollection' } }
                   },
                   required: ['masterportal_collections']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          collection_data = JSON.parse(response.body)['data']['masterportal_collections'].first

          expect(collection_data['collection_id']).to eq('trinkbrunnen')
          expect(collection_data['endpoint_url']).to eq('https://geo.example.org/wfs')
          expect(collection_data.keys).not_to include('import_status', 'import_error', 'last_imported_count')
        end
      end

      response '200', 'collections found with public_data access' do
        let(:projekt_phase_id) { pin_phase.id }

        before { api_client.update!(access_level: :public_data) }

        run_test! do |response|
          collection_data = JSON.parse(response.body)['data']['masterportal_collections'].first

          expect(collection_data['name']).to eq('Trinkbrunnen')
          expect(collection_data.keys).not_to include('endpoint_url', 'create_domain_records')
        end
      end

      response '403', 'phase hidden from public_data clients' do
        let(:projekt_phase_id) { pin_phase.id }

        before do
          api_client.update!(access_level: :public_data)
          pin_phase.update!(frontend_visibility: false)
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { pin_phase.id } }
    end
  end
end
