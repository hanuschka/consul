# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budget Phases API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  let(:existing_budget) do
    create_projekt_phase('ProjektPhase::BudgetPhase').reload.budget
  end

  path '/api/budgets/{budget_id}/budget_phases' do
    parameter name: :budget_id, in: :path, type: :integer, description: 'Budget ID'

    get 'List budget phases' do
      tags 'Budget Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all workflow phases for a budget. Each budget has 9 phases: informing, accepting, reviewing, selecting, valuating, publishing_prices, balloting, reviewing_ballots, finished. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'budget phases returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { budget_phase.reload.budget }
        let(:budget_id) { test_budget.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_phases: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer },
                           kind: { type: :string },
                           name: { type: :string },
                           starts_at: { type: :string, nullable: true },
                           ends_at: { type: :string, nullable: true },
                           enabled: { type: :boolean }
                         }
                       }
                     }
                   },
                   required: ['budget_phases']
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
          phases = data['data']['budget_phases']
          expect(phases.size).to eq(9)
          expect(phases.map { |p| p['kind'] }).to include('informing', 'accepting', 'balloting', 'finished')
        end
      end

      response '404', 'budget not found' do
        let(:budget_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:budget_id) { 1 } }
    end
  end

  path '/api/budget_phases/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget Phase ID'

    get 'Retrieve a budget phase' do
      tags 'Budget Phases'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single budget phase by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'budget phase returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { budget_phase.reload.budget }
        let(:id) { test_budget.phases.find_by(kind: 'accepting').id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_phase: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         kind: { type: :string },
                         name: { type: :string },
                         starts_at: { type: :string, nullable: true },
                         ends_at: { type: :string, nullable: true },
                         enabled: { type: :boolean }
                       }
                     }
                   },
                   required: ['budget_phase']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget_phase']['kind']).to eq('accepting')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a budget phase' do
      tags 'Budget Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a budget phase's dates and enabled status. Use this to configure the budget workflow timeline. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget_phase, in: :body, description: 'Budget phase attributes to update', schema: {
        type: :object,
        properties: {
          budget_phase: {
            type: :object,
            properties: {
              starts_at: { type: :string, nullable: true, description: 'Phase start date (YYYY-MM-DD)' },
              ends_at: { type: :string, nullable: true, description: 'Phase end date (YYYY-MM-DD)' },
              enabled: { type: :boolean, nullable: true, description: 'Enable or disable this phase' }
            }
          }
        },
        required: ['budget_phase']
      }

      response '200', 'budget phase updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { projekt_phase.reload.budget }
        let(:accepting_phase) { test_budget.phases.find_by(kind: 'accepting') }
        let(:id) { accepting_phase.id }
        let(:budget_phase) do
          {
            budget_phase: {
              starts_at: 20.days.from_now.to_date.to_s,
              ends_at: 50.days.from_now.to_date.to_s,
              enabled: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_phase: { type: :object }
                   },
                   required: ['budget_phase']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget_phase']['kind']).to eq('accepting')
          expect(data['data']['budget_phase']['enabled']).to eq(true)
        end
      end

      response '200', 'budget phase disabled' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { projekt_phase.reload.budget }
        let(:reviewing_phase) { test_budget.phases.find_by(kind: 'reviewing') }
        let(:id) { reviewing_phase.id }
        let(:budget_phase) do
          {
            budget_phase: {
              enabled: false
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_phase: { type: :object }
                   },
                   required: ['budget_phase']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget_phase']['enabled']).to eq(false)
        end
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { projekt_phase.reload.budget }
        let(:id) { test_budget.phases.find_by(kind: 'accepting').id }
        let(:budget_phase) do
          {
            budget_phase: {
              enabled: false
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

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/budgets/{budget_id}/budget_phases/bulk_update' do
    parameter name: :budget_id, in: :path, type: :integer, description: 'Budget ID'

    patch 'Bulk update budget phases' do
      tags 'Budget Phases'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update several budget phases of a budget in one request. Each entry is matched by its phase kind (e.g. accepting, balloting) and may set starts_at, ends_at, and/or enabled. All entries are applied first and then every updated phase is validated against the result, so phases can be moved together; the request is rejected with 422 for any value a single phase update would reject (an end date before the start date, a start date before the previous enabled phase's start, an end date after the next enabled phase's end), and for an unknown kind. A rejected request changes no phase. Returns all updated phases. A body without a `budget_phases` array returns 400. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget_phases, in: :body, description: 'Array of phase updates keyed by phase kind', schema: {
        type: :object,
        properties: {
          budget_phases: {
            type: :array,
            items: {
              type: :object,
              properties: {
                kind: { type: :string, description: 'Phase kind to update (e.g. informing, accepting, balloting, finished)' },
                starts_at: { type: :string, nullable: true, description: 'Phase start date (YYYY-MM-DD)' },
                ends_at: { type: :string, nullable: true, description: 'Phase end date (YYYY-MM-DD)' },
                enabled: { type: :boolean, nullable: true, description: 'Enable or disable this phase' }
              },
              required: ['kind']
            }
          }
        },
        required: ['budget_phases']
      }

      response '200', 'budget phases updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { budget_phase.reload.budget }
        let(:budget_id) { test_budget.id }
        let(:budget_phases) do
          {
            budget_phases: [
              {
                kind: 'informing',
                starts_at: (Date.current - 2.months).iso8601,
                ends_at: (Date.current - 1.month).iso8601
              },
              {
                kind: 'accepting',
                starts_at: (Date.current - 1.month).iso8601,
                ends_at: (Date.current + 1.month).iso8601,
                enabled: true
              },
              { kind: 'reviewing', enabled: false }
            ]
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_phases: { type: :array, items: { type: :object } }
                   },
                   required: ['budget_phases']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'dates a single phase update would reject' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { budget_phase.reload.budget }
        let(:budget_id) { test_budget.id }
        let(:budget_phases) do
          {
            budget_phases: [
              { kind: 'reviewing', enabled: false },
              {
                kind: 'accepting',
                starts_at: (Date.current + 2.months).iso8601,
                ends_at: (Date.current + 1.month).iso8601
              }
            ]
          }
        end

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          messages = JSON.parse(response.body)['error']['messages']

          expect(messages).to include(a_string_starting_with('accepting: '))
          expect(test_budget.phases.find_by!(kind: 'reviewing').enabled).to be true
        end
      end

      response '400', 'budget_phases missing or not an array' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:budget_id) { budget_phase.reload.budget.id }
        let(:budget_phases) { { budget_phases: { kind: 'accepting' } } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('bad_request')
        end
      end

      response '422', 'unknown phase kind' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:budget_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { budget_phase.reload.budget }
        let(:budget_id) { test_budget.id }
        let(:budget_phases) do
          { budget_phases: [{ kind: 'nonexistent', enabled: true }] }
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

        run_test!
      end

      unauthorized_response { let(:budget_id) { 1 } }
      forbidden_response { let(:budget_id) { existing_budget.id } }
    end
  end
end
