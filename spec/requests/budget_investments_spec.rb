# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budget Investments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
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
    budget = Budget.create!(name: "Test Budget #{SecureRandom.hex(2)}")
    group = budget.groups.create!(name: "Group #{SecureRandom.hex(2)}")
    heading = group.headings.create!(
      name: "Heading #{SecureRandom.hex(2)}",
      price: 1000000,
      allow_custom_content: true
    )
    [user, budget, heading]
  end

  path '/api/budget_investments' do
    get 'List budget investments' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'
      parameter name: :budget_id, in: :query, type: :integer, required: false, description: 'Filter by budget ID'
      parameter name: :heading_id, in: :query, type: :integer, required: false, description: 'Filter by heading ID'
      parameter name: :group_id, in: :query, type: :integer, required: false, description: 'Filter by group ID'
      parameter name: :feasibility, in: :query, type: :string, required: false, description: 'Filter by feasibility (feasible, unfeasible, undecided)'
      parameter name: :selected, in: :query, type: :string, required: false, description: 'Filter by selection status (true, false)'
      parameter name: :order, in: :query, type: :string, required: false, description: 'Sort order (id, supports, confidence_score, price, ballots, newest)'

      response '200', 'budget investments found' do
        before do
          _user, budget, heading = create_minimal_prereqs
          2.times do |i|
            investment = Budget::Investment.new(
              api_client_created: api_client,
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
            investment.save!(context: :api)
          end
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
        let(:budget) { Budget.create!(name: 'Test Budget') }
        let(:group) { budget.groups.create!(name: 'Test Group') }
        let(:heading) { group.headings.create!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }

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
    end
  end

  path '/api/budget_investments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget Investment ID'

    get 'Retrieve a budget investment' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'budget investment found' do
        let(:budget) { Budget.create!(name: 'Test Budget') }
        let(:group) { budget.groups.create!(name: 'Test Group') }
        let(:heading) { group.headings.create!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            api_client_created: api_client,
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
          investment.save!(context: :api)
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
        let(:id) { 999999 }
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
        let(:budget) { Budget.create!(name: 'Test Budget') }
        let(:group) { budget.groups.create!(name: 'Test Group') }
        let(:heading) { group.headings.create!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            api_client_created: api_client,
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
          investment.save!(context: :api)
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
        let(:budget) { Budget.create!(name: 'Test Budget') }
        let(:group) { budget.groups.create!(name: 'Test Group') }
        let(:heading) { group.headings.create!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            api_client_created: api_client,
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
          investment.save!(context: :api)
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
          allow_any_instance_of(Budget::Investment).to receive(:update).and_return(false)
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
    end
  end
end
