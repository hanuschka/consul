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
      description "Retrieve the text drafts of a text participation (legislation) phase, oldest first. Each draft carries its title, changelog, text (Markdown `body` plus the rendered `body_html`) and status. Clients with `public_data` access only receive published drafts, and only for phases that are active and visible in the frontend; other phases return 403. A phase without drafts returns an empty list.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      let(:projekt) { Projekt.create!(name: 'Projekt') }
      let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
      let(:projekt_phase_id) { legislation_phase.id }
      let(:legislation_process) { legislation_phase.reload.legislation_process }

      texts_response_schema = {
        type: :object,
        properties: {
          data: {
            type: :object,
            properties: {
              texts: {
                type: :array,
                items: { '$ref' => '#/components/schemas/LegislationDraftVersion' }
              }
            },
            required: ['texts']
          },
          pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
        },
        required: ['data', 'pagination']
      }

      response '200', 'only published texts returned for public_data access' do
        before do
          api_client.update!(access_level: :public_data)
          legislation_process.draft_versions.create!(title: 'Published draft', status: 'published')
          legislation_process.draft_versions.create!(title: 'Unpublished draft', status: 'draft')
        end

        schema texts_response_schema

        run_test! do |response|
          texts = JSON.parse(response.body)['data']['texts']

          expect(texts.map { |text| text['title'] }).to eq ['Published draft']
        end
      end

      response '200', 'phase without texts returns an empty list' do
        schema texts_response_schema

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['texts']).to eq []
        end
      end

      response '200', 'texts found and returned' do
        before do
          legislation_process.draft_versions.create!(
            title: 'First draft',
            changelog: 'Initial version',
            body: '# Heading',
            status: 'published'
          )
          legislation_process.draft_versions.create!(
            title: 'Second draft',
            body: 'Work in progress',
            status: 'draft'
          )
        end

        schema texts_response_schema

        run_test! do |response|
          texts = JSON.parse(response.body)['data']['texts']

          expect(texts.map { |text| text['title'] }).to eq ['First draft', 'Second draft']
          expect(texts.first['body_html']).to include('<h1')
        end
      end

      response '403', 'forbidden - phase not active or not visible in the frontend for public_data access' do
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: false) }

        before { api_client.update!(access_level: :public_data) }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end
end
