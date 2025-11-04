# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budgets API', type: :request do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/budgets' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    post 'Create a budget' do
      tags 'Budgets'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :budget, in: :body, description: 'Budget creation payload', schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              name: { type: :string },
              phase: { type: :string },
              currency_symbol: { type: :string },
              voting_style: { type: :string },
              published: { type: :boolean },
              slug: { type: :string }
            },
            required: ['name']
          }
        },
        required: ['budget']
      }

      response '201', 'budget created' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt).id }
        let(:budget) do
          {
            budget: {
              name: 'Test Budget',
              currency_symbol: '$',
              voting_style: 'knapsack',
              published: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget: { type: :object }
                   },
                   required: ['budget']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget']['name']).to eq('Test Budget')
        end
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt).id }
        let(:budget) do
          {
            budget: {
              name: ''
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt).id }
        let(:budget) do
          {
            budget: {
              name: 'Test Budget'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
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

  path '/api/budgets/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget ID'

    get 'Retrieve a budget' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'budget found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget: { type: :object }
                   },
                   required: ['budget']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Test Budget', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'test-budget') }
        let(:id) { test_budget.id }

        run_test!
      end

      response '404', 'budget not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Test Budget', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'test-budget') }
        let(:id) { test_budget.id }

        before do
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    patch 'Update a budget' do
      tags 'Budgets'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :budget, in: :body, description: 'Attributes to update on the budget', schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              name: { type: :string },
              currency_symbol: { type: :string },
              voting_style: { type: :string },
              published: { type: :boolean }
            }
          }
        },
        required: ['budget']
      }

      response '200', 'budget updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Original Name', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'original-name') }
        let(:id) { test_budget.id }
        let(:budget) do
          {
            budget: {
              name: 'Updated Name'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget: { type: :object }
                   },
                   required: ['budget']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'budget not found' do
        let(:id) { 999999 }
        let(:budget) do
          {
            budget: {
              name: 'Updated Name'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Original Name', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'original-name') }
        let(:id) { test_budget.id }
        let(:budget) do
          {
            budget: {
              name: ''
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :array }
                   }
                 }
               }

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Original Name', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'original-name') }
        let(:id) { test_budget.id }
        let(:budget) do
          {
            budget: {
              name: 'Updated Name'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    delete 'Delete a budget' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'budget deleted' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'To Delete', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'to-delete') }
        let(:id) { test_budget.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'budget not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete budget' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Cannot Delete', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'cannot-delete') }
        let(:id) { test_budget.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        before do
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete budget'] })

          allow_any_instance_of(Budget).to receive(:destroy).and_return(false)
          allow_any_instance_of(Budget).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'To Delete', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'to-delete') }
        let(:id) { test_budget.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
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
