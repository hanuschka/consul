# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budgets API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an access_token
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/budgets' do
    get 'List all budgets' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all participatory budgets across all projects. Includes budget details (name, currency, slug) and associated investment information. Useful for overview pages and budget selection. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Page number for pagination (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of budgets per page (**default:** 100, max: 500)', required: false

      response '200', 'budgets found and returned' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:budget_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::BudgetPhase', active: true) }
        let(:budget_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::BudgetPhase', active: true) }

        before do
          Budget.create!(name_en: 'Budget 1', projekt_phase_id: budget_phase1.id, currency_symbol: '$', slug: 'budget-1')
          Budget.create!(name_en: 'Budget 2', projekt_phase_id: budget_phase2.id, currency_symbol: '€', slug: 'budget-2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budgets: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['budgets']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/projekt_phases/{projekt_phase_id}/budgets' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List budgets for a projekt phase' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all budgets associated with a specific projekt phase. Each budget within a phase represents a separate participatory budgeting instance with its own investments and voting. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Page number for pagination (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of budgets per page (**default:** 100, max: 500)', required: false

      response '200', 'budgets found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:budget_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::BudgetPhase', active: true) }
        let(:projekt_phase_id) { budget_phase.id }

        before do
          Budget.create!(name_en: 'Budget 1', projekt_phase_id: budget_phase.id, currency_symbol: '$', slug: 'budget-1')
          Budget.create!(name_en: 'Budget 2', projekt_phase_id: budget_phase.id, currency_symbol: '€', slug: 'budget-2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budgets: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['budgets']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a budget' do
      tags 'Budgets'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new participatory budget for a projekt phase. Budgets define spending priorities, voting mechanisms, and investment categories. Supports optional image attachments for budget visualization or branding. Supports multiple voting styles (knapsack, plurality, etc.) and currency configurations. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget, in: :body, description: 'Budget configuration with required name and optional currency, voting style, publication settings, heading attributes and image attachment', schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              name: { type: :string, description: 'Budget display name (required, must be unique within phase)' },
              phase: { type: :string, nullable: true, description: 'Optional: budget phase identifier' },
              currency_symbol: { type: :string, nullable: true, description: 'Currency symbol to display (e.g., $, €, £, ¥)' },
              voting_style: { type: :string, nullable: true, description: 'Voting mechanism type: "knapsack", "approval", or "distributed"' },
              published: { type: :boolean, nullable: true, description: 'Whether the budget is visible to the public' },
              slug: { type: :string, nullable: true, description: 'URL-friendly identifier for the budget (auto-generated if not provided)' },
              hide_money: { type: :boolean, nullable: true, description: 'Hide monetary values from public view' },
              max_number_of_winners: { type: :integer, nullable: true, description: 'Maximum number of winning proposals (0 = unlimited)' },
              show_results_after_first_vote: { type: :boolean, nullable: true, description: 'Show voting results in real time after the first vote' },
              show_percentage_values_only: { type: :boolean, nullable: true, description: 'Display only percentage values instead of absolute numbers' },
              max_preselected: { type: :integer, nullable: true, description: 'Maximum number of pre-selected proposals (0 = disabled)' },
              heading_attributes: {
                type: :object,
                nullable: true,
                description: 'Budget heading configuration: total amount, population and ballot limits',
                properties: {
                  id: { type: :integer, nullable: true, description: 'Heading ID (required for updates)' },
                  price: { type: :integer, nullable: true, description: 'Total budget amount for this heading' },
                  population: { type: :integer, nullable: true, description: 'Population count for this heading' },
                  max_ballot_lines: { type: :integer, nullable: true, description: 'Maximum ballot lines per voter' }
                }
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Optional: Image for budget branding or visualization. Upload as base64-encoded data.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Image caption or alt text' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file (JPEG, PNG, GIF, WebP, max 5MB)' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Image source attribution or copyright' },
                  ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image' }
                }
              }
            },
            required: ['name']
          }
        },
        required: ['budget']
      }

      response '201', 'budget created successfully' do
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
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '201', 'budget created with heading and settings' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt).id }
        let(:budget) do
          {
            budget: {
              name: 'Configured Budget',
              currency_symbol: '€',
              voting_style: 'approval',
              published: true,
              hide_money: false,
              max_number_of_winners: 10,
              show_results_after_first_vote: true,
              show_percentage_values_only: false,
              max_preselected: 5,
              heading_attributes: {
                price: 250_000,
                population: 50_000,
                max_ballot_lines: 3
              }
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
          expect(data['data']['budget']['name']).to eq('Configured Budget')
          expect(data['data']['budget']['voting_style']).to eq('approval')
          expect(response.status).to eq(201)
        end
      end

      response '201', 'budget created with base64 image' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt).id }
        let(:budget) do
          {
            budget: {
              name: 'Test Budget',
              currency_symbol: '$',
              voting_style: 'knapsack',
              published: true,
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Budget Cover Image'
              }
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
          expect(data['data']['budget']).to be_present
          expect(response.status).to eq(201)
        end
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/budgets/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget ID'

    get 'Retrieve a budget' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single budget by ID with all configuration details. Returns budget metadata (name, currency, voting style), phase information, and statistics about associated investments. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'budget found and returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Test Budget', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'test-budget') }
        let(:id) { test_budget.id }

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

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a budget' do
      tags 'Budgets'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update budget configuration such as name, voting style, currency, publication status, or image. Can add, replace, or remove the budget image. All fields are optional - only provide fields to change. Returns the updated budget object. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget, in: :body, description: 'Budget attributes to update. Any field not provided remains unchanged.', schema: {
        type: :object,
        properties: {
          budget: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true, description: 'Budget display name' },
              phase: { type: :string, nullable: true, description: 'Budget phase identifier' },
              currency_symbol: { type: :string, nullable: true, description: 'Currency symbol (€, $, £, ¥)' },
              voting_style: { type: :string, nullable: true, description: 'Voting mechanism: "knapsack", "approval", or "distributed"' },
              published: { type: :boolean, nullable: true, description: 'Publish or unpublish the budget' },
              slug: { type: :string, nullable: true, description: 'URL-friendly identifier' },
              hide_money: { type: :boolean, nullable: true, description: 'Hide monetary values from public view' },
              max_number_of_winners: { type: :integer, nullable: true, description: 'Maximum number of winning proposals' },
              show_results_after_first_vote: { type: :boolean, nullable: true, description: 'Show results in real time' },
              show_percentage_values_only: { type: :boolean, nullable: true, description: 'Display only percentages' },
              max_preselected: { type: :integer, nullable: true, description: 'Maximum pre-selected proposals' },
              heading_attributes: {
                type: :object,
                nullable: true,
                description: 'Budget heading: total amount, population and ballot limits',
                properties: {
                  id: { type: :integer, nullable: true, description: 'Heading ID (required for updates)' },
                  price: { type: :integer, nullable: true, description: 'Total budget amount' },
                  population: { type: :integer, nullable: true, description: 'Population count' },
                  max_ballot_lines: { type: :integer, nullable: true, description: 'Maximum ballot lines per voter' }
                }
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Update, replace or remove budget image via base64-encoded data.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Image caption or alt text' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file (JPEG, PNG, GIF, WebP, max 5MB)' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Image source attribution or copyright' },
                  ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image' }
                }
              }
            }
          }
        },
        required: ['budget']
      }

      response '200', 'budget updated successfully' do
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
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'budget updated with heading and settings' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Original', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'original') }
        let(:id) { test_budget.id }
        let(:budget) do
          {
            budget: {
              currency_symbol: '€',
              voting_style: 'approval',
              hide_money: false,
              max_number_of_winners: 15,
              show_results_after_first_vote: true,
              heading_attributes: {
                id: test_budget.heading&.id,
                price: 500_000
              }
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
          expect(data['data']['budget']['currency_symbol']).to eq('€')
          expect(data['data']['budget']['voting_style']).to eq('approval')
        end
      end

      response '200', 'budget updated with base64 image' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::BudgetPhase.create!(projekt: test_projekt) }
        let(:test_budget) { Budget.create!(name_en: 'Original Name', projekt_phase_id: projekt_phase.id, currency_symbol: '$', slug: 'original-name') }
        let(:id) { test_budget.id }
        let(:budget) do
          {
            budget: {
              name: 'Updated Name',
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Updated Budget Image'
              }
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
          expect(data['data']['budget']).to be_present
          expect(response.status).to eq(200)
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a budget' do
      tags 'Budgets'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a budget and all associated investments and voting data. This action is permanent and cannot be undone. All data related to this budget will be removed. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'budget deleted successfully' do
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
end
