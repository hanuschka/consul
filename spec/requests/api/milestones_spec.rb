# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestones API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  MILESTONE_PARAMS = {
    type: :object,
    properties: {
      title: { type: :string, description: 'Milestone title (max 80 characters)' },
      description: { type: :string, description: 'Milestone description. Required unless status_id is provided.' },
      publication_date: { type: :string, format: :date, description: 'Publication date in YYYY-MM-DD format. Required.' },
      custom_date: { type: :string, nullable: true, description: 'Custom display date text (optional)' },
      status_id: { type: :integer, nullable: true, description: 'Milestone status ID (optional). When provided, description becomes optional.' }
    }
  }.freeze

  MILESTONE_PARAM_SCHEMA = {
    type: :object,
    properties: {
      milestone: MILESTONE_PARAMS
    },
    required: ['milestone']
  }.freeze

  path '/api/projekt_phases/{projekt_phase_id}/milestones' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (MilestonePhase)'

    get 'List all milestones' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all milestones for a projekt phase. Milestones track project progress over time and include status updates.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'milestones found and returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:milestone_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { milestone_phase.id }
        let!(:milestone) do
          milestone_phase.milestones.create!(
            title: 'Phase 1 Complete',
            description: 'First phase completed successfully',
            publication_date: Date.current
          )
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestones'].length).to eq(1)
          expect(data['data']['milestones'][0]['title']).to eq('Phase 1 Complete')
        end
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new milestone for a MilestonePhase. Milestones require a publication_date and either a description or a status_id.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :milestone, in: :body, description: 'Milestone attributes', schema: MILESTONE_PARAM_SCHEMA

      response '201', 'milestone created successfully' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:milestone_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { milestone_phase.id }
        let(:milestone) do
          {
            milestone: {
              title: 'Construction Started',
              description: 'Ground breaking ceremony and construction begins',
              publication_date: '2026-05-01'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestone']['title']).to eq('Construction Started')
          expect(data['data']['milestone']['publication_date']).to include('2026-05-01')
        end
      end

      response '201', 'milestone created with status_id instead of description' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:milestone_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { milestone_phase.id }
        let!(:status) { Milestone::Status.create!(name: 'In Progress') }
        let(:milestone) do
          {
            milestone: {
              title: 'Phase 2',
              publication_date: '2026-06-15',
              status_id: status.id
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestone']['status_id']).to eq(status.id)
        end
      end

      response '422', 'missing required fields' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:milestone_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:projekt_phase_id) { milestone_phase.id }
        let(:milestone) do
          {
            milestone: {
              title: 'No date or description'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['messages']).to be_present
        end
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }
        let(:milestone) do
          {
            milestone: {
              title: 'Test',
              description: 'Test',
              publication_date: '2026-01-01'
            }
          }
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }

      forbidden_response { let(:projekt_phase_id) { 1 } }
    end
  end
end
