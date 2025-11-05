# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budget Investments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin).tap(&:reload) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  def create_minimal_prereqs
    geozone = Geozone.create!(name: "Zone #{SecureRandom.hex(2)}")
    user = User.create!(
      username: "user_#{SecureRandom.hex(4)}",
      email: "u_#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      geozone: geozone,
      terms_data_storage: '1',
      terms_data_protection: '1',
      terms_general: '1'
    )
    budget = Budget.create!(name: "Test Budget #{SecureRandom.hex(2)}", currency_symbol: '€')
    group = budget.create_group!(name: "Group #{SecureRandom.hex(2)}")
    heading = group.create_heading!(
      name: "Heading #{SecureRandom.hex(2)}",
      price: 1000000,
      allow_custom_content: true
    )
    [user, budget, heading]
  end

  path '/api/budgets/{budget_id}/investments' do
    parameter name: :budget_id, in: :path, type: :integer, description: 'Budget ID'

    get 'List budget investments' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'
      parameter name: :heading_id, in: :query, type: :integer, required: false, description: 'Filter by heading ID'
      parameter name: :group_id, in: :query, type: :integer, required: false, description: 'Filter by group ID'
      parameter name: :feasibility, in: :query, type: :string, required: false, description: 'Filter by feasibility (feasible, unfeasible, undecided)'
      parameter name: :selected, in: :query, type: :string, required: false, description: 'Filter by selection status (true, false)'
      parameter name: :order, in: :query, type: :string, required: false, description: 'Sort order (id, supports, confidence_score, price, ballots, newest)'

      response '200', 'budget investments found' do
        let(:budget_id) do
          _user, budget, heading = create_minimal_prereqs
          2.times do |i|
            investment = Budget::Investment.new(
              author: api_client.user,
              heading: heading,
              budget: budget,
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Investment #{i+1}",
                  description: "Description #{i+1}"
                }
              ]
            )
            investment.save!
          end
          budget.id
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investments: { type: :array, items: { type: :object } }
                   },
                   required: ['budget_investments']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:budget_id) { Budget.create!(name: 'Test Budget', currency_symbol: '€').id }
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

      response '200', 'budget investments found with public_data access' do
        let(:budget_id) do
          api_client.update!(access_level: :public_data)
          _user, budget, heading = create_minimal_prereqs
          2.times do |i|
            investment = Budget::Investment.new(
              author: api_client.user,
              heading: heading,
              budget: budget,
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Investment #{i+1}",
                  description: "Description #{i+1}"
                }
              ]
            )
            investment.save!
          end
          budget.id
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investments: { type: :array, items: { type: :object } }
                   },
                   required: ['budget_investments']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a budget investment' do
      tags 'Budget Investments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :budget_investment, in: :body, description: 'Budget investment payload', schema: {
        type: :object,
        properties: {
          budget_investment: {
            type: :object,
            properties: {
              heading_id: { type: :integer },
              title: { type: :string },
              description: { type: :string },
              video_url: { type: :string, nullable: true },
              on_behalf_of: { type: :string, nullable: true },
              resource_terms: { type: :boolean },
              price: { type: :number, nullable: true },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number },
                  longitude: { type: :number },
                  zoom: { type: :integer }
                },
                required: %w[latitude longitude]
              },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string },
                    description: { type: :string }
                  }
                }
              },
              tag_list: {
                type: :array,
                items: { type: :string }
              }
            },
            required: %w[heading_id title description resource_terms]
          }
        },
        required: ['budget_investment']
      }

      response '201', 'budget investment created' do
        let(:budget_id) { Budget.create!(name: 'Test Budget', currency_symbol: '€').id }
        let(:budget) { Budget.find(budget_id) }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }

        let(:budget_investment) do
          {
            budget_investment: {
              heading_id: heading.id,
              title: 'New Budget Investment',
              description: 'A meaningful description for the investment',
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: 'New Budget Investment',
                  description: 'A meaningful description for the investment'
                }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investment: { type: :object }
                   },
                   required: ['budget_investment']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:budget_id) { Budget.create!(name: 'Test Budget', currency_symbol: '€').id }
        let(:budget_investment) do
          {
            budget_investment: {
              title: '',
              description: ''
            }
          }
        end

        before do
          allow_any_instance_of(Budget::Investment).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(Budget::Investment).to receive(:errors).and_return(errors_mock)
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

      response '403', 'forbidden - admin access required' do
        let(:budget_id) do
          api_client.update!(access_level: :public_data)
          Budget.create!(name: 'Test Budget', currency_symbol: '€').id
        end
        let(:budget) { Budget.find(budget_id) }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }

        let(:budget_investment) do
          {
            budget_investment: {
              heading_id: heading.id,
              title: 'New Budget Investment',
              description: 'A meaningful description for the investment',
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: 'New Budget Investment',
                  description: 'A meaningful description for the investment'
                }
              ]
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
    end
  end

  path '/api/budgets/{budget_id}/investments/{id}' do
    parameter name: :budget_id, in: :path, type: :integer, description: 'Budget ID'
    parameter name: :id, in: :path, type: :integer, description: 'Budget Investment ID'

    get 'Retrieve a budget investment' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'budget investment found' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Test Investment',
                description: 'Test Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investment: { type: :object }
                   },
                   required: ['budget_investment']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'budget investment not found' do
        let(:budget_id) { Budget.create!(name: 'Test Budget', currency_symbol: '€').id }
        let(:id) { 999999 }
        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Test Investment',
                description: 'Test Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }
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

      response '200', 'budget investment found with public_data access' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Test Investment',
                description: 'Test Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }
        before do
          api_client.update!(access_level: :public_data)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investment: { type: :object }
                   },
                   required: ['budget_investment']
                 }
               },
               required: ['data']

        run_test!
      end
    end

    patch 'Update a budget investment' do
      tags 'Budget Investments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :budget_investment, in: :body, description: 'Attributes to update on the budget investment', schema: {
        type: :object,
        properties: {
          budget_investment: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              video_url: { type: :string, nullable: true },
              on_behalf_of: { type: :string, nullable: true },
              price: { type: :number, nullable: true },
              feasibility: { type: :string, nullable: true, enum: %w[feasible unfeasible undecided] },
              valuation_finished: { type: :boolean, nullable: true },
              selected: { type: :boolean, nullable: true },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string, nullable: true },
                    description: { type: :string, nullable: true }
                  }
                }
              },
              tag_list: {
                type: :array,
                items: { type: :string }
              }
            }
          }
        }
      }

      response '200', 'budget investment updated' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Investment',
                description: 'Original Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { existing_investment.id }
        let(:budget_investment) do
          {
            budget_investment: {
              description: 'Updated description'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investment: { type: :object }
                   },
                   required: ['budget_investment']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Investment',
                description: 'Original Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { existing_investment.id }
        let(:budget_investment) do
          {
            budget_investment: {
              title: ''
            }
          }
        end

        before do
          allow_any_instance_of(Budget::Investment).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(Budget::Investment).to receive(:errors).and_return(errors_mock)
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

      response '403', 'forbidden - admin access required' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:budget_id) { budget.id }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Investment',
                description: 'Original Description'
              }
            ]
          )
          investment.save!
          investment
        end
        let(:id) { existing_investment.id }
        before do
          api_client.update!(access_level: :public_data)
        end
        let(:budget_investment) do
          {
            budget_investment: {
              description: 'Updated description'
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
    end
  end
end
