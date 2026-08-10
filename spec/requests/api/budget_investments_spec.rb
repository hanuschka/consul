# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Budget Investments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

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
      description "Retrieve all budget investments (project proposals) for a specific participatory budget. Investments can be filtered by category (heading/group), feasibility status, selection status, and sorted by various criteria. Returns paginated results with voting/support information.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'
      parameter name: :heading_id, in: :query, type: :integer, required: false, description: 'Filter results to investments in a specific category heading'
      parameter name: :group_id, in: :query, type: :integer, required: false, description: 'Filter results to investments in a specific category group'
      parameter name: :feasibility, in: :query, type: :string, required: false, description: 'Filter by feasibility assessment: "feasible", "unfeasible", or "undecided"'
      parameter name: :selected, in: :query, type: :string, required: false, description: 'Filter by selection status: "true" for selected investments, "false" for unselected'
      parameter name: :order, in: :query, type: :string, required: false, description: 'Sort by: "id" (**default**), "supports" (vote count), "confidence_score", "price", "ballots", or "newest"'

      response '200', 'budget investments found and returned' do
        let(:budget_id) do
          _user, budget, heading = create_minimal_prereqs
          2.times do |i|
            investment = Budget::Investment.new(
              author: api_client.user,
              heading: heading,
              budget: budget,
              resource_terms: true,
              title: "Investment #{i}",
              description: "Description for investment #{i}"
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
              title: "Investment #{i}",
              description: "Description for investment #{i}"
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

      unauthorized_response { let(:budget_id) { 1 } }
    end

    post 'Create a budget investment' do
      tags 'Budget Investments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Submit a new budget investment (project proposal) to a specific budget. Investments must be assigned to a category heading and include title, description, and estimated budget/price. Supports video attachments, geographic location mapping, multilingual descriptions, image attachments for project visualization, and tagging. Requires acceptance of terms. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget_investment, in: :body, description: 'Budget investment submission with required heading ID, title, description, and terms acceptance. Optional image attachment for project visualization.', schema: {
        type: :object,
        properties: {
          budget_investment: {
            type: :object,
            properties: {
              heading_id: { type: :integer, description: 'Category heading ID where the investment belongs (required). Defines the project category and budget allocation.' },
              title: { type: :string, description: 'Project title/name (required). Concise name visible to voters.' },
              description: { type: :string, description: 'Detailed project description (required). Explains the investment and its benefits.' },
              video_url: { type: :string, nullable: true, description: 'Optional URL to a demonstration or explanation video. Supports YouTube, Vimeo, etc.' },
              on_behalf_of: { type: :string, nullable: true, description: 'Optional: Organization or group name if the proposal is made on behalf of an entity rather than an individual.' },
              resource_terms: { type: :boolean, description: 'Must be true. Confirms the submitter accepts the terms and conditions.' },
              price: { type: :number, nullable: true, description: 'Estimated budget/cost for the investment in the budget\'s currency.' },
              feasibility: { type: :string, nullable: true, enum: %w[feasible unfeasible undecided], description: 'Admin feasibility assessment (admin only). Set to "feasible" (can be completed), "unfeasible" (cannot be done), or "undecided" (still evaluating).' },
              valuation_finished: { type: :boolean, nullable: true, description: 'Admin-only: Whether feasibility assessment is complete' },
              selected: { type: :boolean, nullable: true, description: 'Admin-only: Whether this investment is selected as a winner' },
              visible_to_valuators: { type: :boolean, nullable: true, description: 'Admin-only: Whether this investment is visible to valuators during the assessment phase' },
              map_location_attributes: {
                type: :object,
                nullable: true,
                description: 'Geographic location data for mapping the investment',
                properties: {
                  id: { type: :integer, nullable: true },
                  latitude: { type: :number, description: 'Latitude coordinate' },
                  longitude: { type: :number, description: 'Longitude coordinate' },
                  altitude: { type: :number, nullable: true },
                  zoom: { type: :integer, nullable: true },
                  features: { type: :string, nullable: true },
                  rendering_library: { type: :string, nullable: true },
                  show_admin_shape: { type: :boolean, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                },
                required: %w[latitude longitude]
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Optional: Image to visualize the investment project (rendering, photo, diagram, etc.). Upload as base64-encoded data. Recommended for presenting visual evidence or demonstrating the project concept.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image. Helps visually-impaired users understand the image content.' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information. Displayed with the image to give proper credit.' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the budget investment. Does not affect other investment properties.' }
                }
              },
              documents_attributes: {
                type: :array,
                nullable: true,
                description: 'Array of document attachments (PDFs, Word docs, spreadsheets, etc.) to support the investment proposal. Upload documents as base64-encoded data.',
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    title: { type: :string, nullable: true, description: 'Document title or filename' },
                    attachment: { type: :string, nullable: true, description: 'Base64-encoded document file. Supported formats: PDF, DOC, DOCX, XLS, XLSX, etc.' },
                    cached_attachment: { type: :string, nullable: true },
                    user_id: { type: :integer, nullable: true },
                    _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove this document' }
                  }
                }
              },
              tag_list: {
                type: :array,
                items: { type: :string },
                description: 'Optional: Comma-separated or array of tags for categorization and searching.'
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
              resource_terms: true
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
              resource_terms: true
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

      response '201', 'budget investment created with base64 image' do
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
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Investment Cover Image'
              }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget_investment']).to be_present
          expect(response.status).to eq(201)
        end
      end

      unauthorized_response { let(:budget_id) { 1 } }
    end
  end

  path '/api/budget_investments' do
    get 'List all budget investments' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all budget investments across all budgets. Includes investment details (title, description, status, cost) and voting/support statistics. Useful for global investment tracking and analytics.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'budget investments found and returned' do
        before do
          _user1, budget1, heading1 = create_minimal_prereqs
          _user2, budget2, heading2 = create_minimal_prereqs

          Budget::Investment.create!(
            author: api_client.user,
            heading: heading1,
            budget: budget1,
            resource_terms: true,
            title: 'Investment 1',
            description: 'Description for investment 1'
          )

          Budget::Investment.create!(
            author: api_client.user,
            heading: heading2,
            budget: budget2,
            resource_terms: true,
            title: 'Investment 2',
            description: 'Description for investment 2'
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     budget_investments: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['budget_investments']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/investments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget Investment ID'

    get 'Retrieve a budget investment' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single budget investment by ID with full details. Returns project information, feasibility assessment, admin valuation status, voting statistics, and selected status.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'budget investment found and returned' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
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
        let(:id) { 999999 }
        run_test!
      end

      response '200', 'budget investment found with public_data access' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
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

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a budget investment' do
      tags 'Budget Investments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a budget investment details. Allows editing project information, admin feasibility assessment, selection status, or image. Can add, replace, or remove the investment image. Admin-only: can set feasibility status and mark as selected. All fields are optional - only provide fields to change. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :budget_investment, in: :body, description: 'Investment attributes to update (title, description, price, feasibility, selection status, image, translations). Any field not provided remains unchanged.', schema: {
        type: :object,
        properties: {
          budget_investment: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true, description: 'Project title' },
              description: { type: :string, nullable: true, description: 'Project description' },
              video_url: { type: :string, nullable: true, description: 'URL to demonstration or explanation video' },
              on_behalf_of: { type: :string, nullable: true, description: 'Organization or group name if applicable' },
              price: { type: :number, nullable: true, description: 'Estimated project cost in budget currency' },
              feasibility: { type: :string, nullable: true, enum: %w[feasible unfeasible undecided], description: 'Admin feasibility assessment (admin only). Set to "feasible" (can be completed), "unfeasible" (cannot be done), or "undecided" (still evaluating).' },
              valuation_finished: { type: :boolean, nullable: true, description: 'Admin-only: Whether feasibility assessment is complete' },
              selected: { type: :boolean, nullable: true, description: 'Admin-only: Whether this investment is selected as a winner' },
              visible_to_valuators: { type: :boolean, nullable: true, description: 'Admin-only: Whether this investment is visible to valuators during the assessment phase' },
              map_location_attributes: {
                type: :object,
                nullable: true,
                description: 'Geographic location data for mapping the investment',
                properties: {
                  id: { type: :integer, nullable: true },
                  latitude: { type: :number, nullable: true, description: 'Latitude coordinate' },
                  longitude: { type: :number, nullable: true, description: 'Longitude coordinate' },
                  altitude: { type: :number, nullable: true },
                  zoom: { type: :integer, nullable: true },
                  features: { type: :string, nullable: true },
                  rendering_library: { type: :string, nullable: true },
                  show_admin_shape: { type: :boolean, nullable: true },
                  _destroy: { type: :boolean, nullable: true }
                }
              },
              image_attributes: {
                type: :object,
                nullable: true,
                description: 'Update, replace, or remove the investment image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove. All fields are optional.',
                properties: {
                  id: { type: :integer, nullable: true },
                  title: { type: :string, nullable: true, description: 'Updated image caption or alt text. Improves accessibility by describing the image content for screen readers.' },
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file to replace current image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB). Omit to keep existing image.' },
                  cached_attachment: { type: :string, nullable: true },
                  credits: { type: :string, nullable: true, description: 'Updated image source attribution, photographer/artist name, or copyright notice. Properly credits original creators.' },
                  user_id: { type: :integer, nullable: true },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image entirely from the budget investment while preserving the investment text and other properties.' }
                }
              },
              documents_attributes: {
                type: :array,
                nullable: true,
                description: 'Update document attachments. Add new documents, update existing ones (provide id), or remove documents (set _destroy=true).',
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true, description: 'ID of existing document when updating. Omit for new documents.' },
                    title: { type: :string, nullable: true, description: 'Document title or filename' },
                    attachment: { type: :string, nullable: true, description: 'Base64-encoded document file. Supported formats: PDF, DOC, DOCX, XLS, XLSX, etc.' },
                    cached_attachment: { type: :string, nullable: true },
                    user_id: { type: :integer, nullable: true },
                    _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove this document' }
                  }
                }
              },
              tag_list: {
                type: :array,
                items: { type: :string },
                description: 'Tags for categorization'
              }
            }
          }
        }
      }

      response '200', 'budget investment updated successfully' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Original Investment',
            description: 'Original Description'
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
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Original Investment',
            description: 'Original Description'
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
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Original Investment',
            description: 'Original Description'
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

      response '200', 'budget investment updated with base64 image' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:existing_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Original Investment',
            description: 'Original Description'
          )
          investment.save!
          investment
        end
        let(:id) { existing_investment.id }
        let(:budget_investment) do
          {
            budget_investment: {
              description: 'Updated description',
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Updated Investment Image'
              }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['budget_investment']).to be_present
          expect(response.status).to eq(200)
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a budget investment' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a budget investment and all associated voting data. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'budget investment deleted successfully' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'budget investment not found' do
        let(:id) { 999999 }
        run_test!
      end

      response '422', 'unable to delete budget investment' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }

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
          allow_any_instance_of(Budget::Investment).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete budget investment'] })
          allow_any_instance_of(Budget::Investment).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
          )
          investment.save!
          investment
        end
        let(:id) { budget_investment.id }

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

  path '/api/budget_investments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Budget Investment ID'

    get 'Retrieve a budget investment (alias)' do
      tags 'Budget Investments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Alias of `GET /api/investments/{id}`. Retrieve a single budget investment by ID with full details. Returns project information, feasibility assessment, admin valuation status, voting statistics, and selected status.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'budget investment found and returned' do
        let(:budget) { Budget.create!(name: 'Test Budget', currency_symbol: '€') }
        let(:group) { budget.create_group!(name: 'Test Group') }
        let(:heading) { group.create_heading!(name: 'Test Heading', price: 1000000, allow_custom_content: true) }
        let(:budget_investment) do
          investment = Budget::Investment.new(
            author: api_client.user,
            heading: heading,
            budget: budget,
            resource_terms: true,
            title: 'Test Investment',
            description: 'Test Description'
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
        let(:id) { 999999 }
        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end
