# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Progress Bars API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  PROGRESS_BAR_PARAMS = {
    type: :object,
    properties: {
      title: { type: :string, description: 'Progress bar label. Required for secondary bars, optional for primary.' },
      kind: { type: :string, enum: %w[primary secondary], description: 'Bar type. Only one primary per phase allowed.' },
      percentage: { type: :integer, description: 'Completion percentage (0-100)' }
    }
  }.freeze

  PROGRESS_BAR_PARAM_SCHEMA = {
    type: :object,
    properties: {
      progress_bar: PROGRESS_BAR_PARAMS
    },
    required: ['progress_bar']
  }.freeze

  path '/api/projekt_phases/{projekt_phase_id}/progress_bars' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List progress bars' do
      tags 'Progress Bars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all progress bars for a projekt phase.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'progress bars returned' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:projekt_phase_id) { phase.id }
        let!(:primary_bar) do
          phase.progress_bars.create!(kind: :primary, percentage: 45)
        end
        let!(:secondary_bar) do
          phase.progress_bars.create!(kind: :secondary, percentage: 70, title: 'Sub-project A')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     progress_bars: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['progress_bars']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   },
                   required: ['current_page', 'total_pages', 'total_count', 'per_page']
                 }
               },
               required: ['data', 'pagination']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['progress_bars'].length).to eq(2)
        end
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a progress bar' do
      tags 'Progress Bars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new progress bar for a projekt phase. Only one primary bar allowed per phase. Secondary bars require a title.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :progress_bar, in: :body, description: 'Progress bar attributes', schema: PROGRESS_BAR_PARAM_SCHEMA

      response '201', 'primary progress bar created' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:projekt_phase_id) { phase.id }
        let(:progress_bar) do
          {
            progress_bar: {
              kind: 'primary',
              percentage: 25
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     progress_bar: { type: :object }
                   },
                   required: ['progress_bar']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['progress_bar']['kind']).to eq('primary')
          expect(data['data']['progress_bar']['percentage']).to eq(25)
        end
      end

      response '201', 'secondary progress bar created' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:projekt_phase_id) { phase.id }
        let(:progress_bar) do
          {
            progress_bar: {
              kind: 'secondary',
              percentage: 60,
              title: 'Sub-project Alpha'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['progress_bar']['kind']).to eq('secondary')
          expect(data['data']['progress_bar']['title']).to eq('Sub-project Alpha')
        end
      end

      response '422', 'duplicate primary bar' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:projekt_phase_id) { phase.id }
        let!(:existing_primary) { phase.progress_bars.create!(kind: :primary, percentage: 10) }
        let(:progress_bar) do
          {
            progress_bar: {
              kind: 'primary',
              percentage: 50
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

      response '422', 'invalid percentage' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:projekt_phase_id) { phase.id }
        let(:progress_bar) do
          {
            progress_bar: {
              kind: 'secondary',
              percentage: 150,
              title: 'Over the limit'
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['messages']).to be_present
        end
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }
        let(:progress_bar) do
          {
            progress_bar: {
              kind: 'primary',
              percentage: 50
            }
          }
        end

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/progress_bars/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Progress Bar ID'

    get 'Retrieve a progress bar' do
      tags 'Progress Bars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single progress bar by ID.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'progress bar found' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:bar) { phase.progress_bars.create!(kind: :primary, percentage: 30) }
        let(:id) { bar.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     progress_bar: { type: :object }
                   },
                   required: ['progress_bar']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'progress bar not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a progress bar' do
      tags 'Progress Bars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a progress bar's percentage, title, or kind.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :progress_bar, in: :body, description: 'Progress bar attributes to update', schema: PROGRESS_BAR_PARAM_SCHEMA

      response '200', 'progress bar updated' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:bar) { phase.progress_bars.create!(kind: :primary, percentage: 30) }
        let(:id) { bar.id }
        let(:progress_bar) do
          {
            progress_bar: {
              percentage: 75
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['progress_bar']['percentage']).to eq(75)
        end
      end

      response '422', 'invalid update' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:bar) { phase.progress_bars.create!(kind: :primary, percentage: 30) }
        let(:id) { bar.id }
        let(:progress_bar) do
          {
            progress_bar: {
              percentage: -5
            }
          }
        end

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['messages']).to be_present
        end
      end

      response '404', 'progress bar not found' do
        let(:id) { 999999 }
        let(:progress_bar) { { progress_bar: { percentage: 50 } } }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end

    delete 'Delete a progress bar' do
      tags 'Progress Bars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a progress bar permanently.#{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'progress bar deleted' do
        let(:projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:phase) { ProjektPhase::MilestonePhase.create!(projekt: projekt) }
        let(:bar) { phase.progress_bars.create!(kind: :secondary, percentage: 50, title: 'To Delete') }
        let(:id) { bar.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'progress bar not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end
end
