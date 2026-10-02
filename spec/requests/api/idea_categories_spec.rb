# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Idea Categories API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def create_idea_officer
    geozone = Geozone.create!(name: "Zone #{SecureRandom.hex(2)}")
    user = User.create!(
      username: "officer_#{SecureRandom.hex(4)}",
      email: "officer_#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      geozone: geozone,
      terms_data_storage: '1',
      terms_data_protection: '1',
      terms_general: '1'
    )
    Idea::Officer.create!(user: user)
  end

  path '/api/idea_categories' do
    get 'List idea categories' do
      tags 'Idea Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all idea categories. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'idea categories found' do
        before do
          2.times do |i|
            Idea::Category.create!(
              name: "Category #{i}"
            )
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_categories: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_categories']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '200', 'idea categories found with public_data access' do
        before do
          api_client.update!(access_level: :public_data)
          2.times do |i|
            Idea::Category.create!(
              name: "Category #{i}"
            )
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_categories: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_categories']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '200', 'idea categories with pagination' do
        before do
          5.times do |i|
            Idea::Category.create!(
              name: "Category #{i}"
            )
          end
        end

        let(:page) { 1 }
        let(:per_page) { 2 }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_categories: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_categories']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['idea_categories'].length).to eq(2)
          expect(data['pagination']['current_page']).to eq(1)
          expect(data['pagination']['total_count']).to eq(5)
        end
      end

      unauthorized_response
    end

    post 'Create an idea category' do
      tags 'Idea Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new idea category for organizing and classifying citizen ideas. Categories help administrators manage ideas thematically. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :idea_category, in: :body, description: 'Idea category payload', schema: {
        type: :object,
        properties: {
          idea_category: {
            type: :object,
            properties: {
              idea_officer_id: { type: :integer, nullable: true }
            },
            required: []
          }
        },
        required: ['idea_category']
      }

      response '201', 'idea category created' do
        let(:idea_category) do
          {
            idea_category: {
              name: 'New Category'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_category: { type: :object }
                   },
                   required: ['idea_category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '201', 'idea category created with default officer' do
        let(:officer) { create_idea_officer }
        let(:idea_category) do
          {
            idea_category: {
              name: 'Category with Officer',
              idea_officer_id: officer.id
            }
          }
        end

        before { officer }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_category: { type: :object }
                   },
                   required: ['idea_category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:idea_category) do
          {
            idea_category: {
              name: 'Forbidden Category'
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

      response '401', 'unauthorized - missing valid token' do
        let(:Authorization) { 'Bearer invalid_token' }

        let(:idea_category) do
          {
            idea_category: {
              name: 'Unauthorized Category'
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
          expect(data['error']['type']).to eq('unauthorized')
        end
      end

      response '422', 'invalid request' do
        let(:idea_category) do
          {
            idea_category: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(Idea::Category).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name can\'t be blank'])
          allow_any_instance_of(Idea::Category).to receive(:errors).and_return(errors_mock)
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

  path '/api/idea_categories/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Idea Category ID'

    get 'Retrieve an idea category' do
      tags 'Idea Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single idea category by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'idea category found' do
        let(:category) do
          Idea::Category.create!(
            name: 'Test Category'
          )
        end
        let(:id) { category.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_category: { type: :object }
                   },
                   required: ['idea_category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'idea category not found' do
        let(:id) { 999999 }
        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update an idea category' do
      tags 'Idea Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing idea category. Allows modifying category name and assigned officer. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :idea_category, in: :body, description: 'Attributes to update on the idea category', schema: {
        type: :object,
        properties: {
          idea_category: {
            type: :object,
            properties: {
              idea_officer_id: { type: :integer, nullable: true }
            }
          }
        }
      }

      response '200', 'idea category updated' do
        let(:existing_category) do
          Idea::Category.create!(
            name: 'Original Category'
          )
        end
        let(:id) { existing_category.id }
        let(:idea_category) do
          {
            idea_category: {
              name: 'Updated Category'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_category: { type: :object }
                   },
                   required: ['idea_category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '200', 'idea category updated with new officer' do
        let(:officer) { create_idea_officer }
        let(:existing_category) do
          Idea::Category.create!(
            name: 'Original Category'
          )
        end
        let(:id) { existing_category.id }
        let(:idea_category) do
          {
            idea_category: {
              name: 'Updated Category with Officer',
              idea_officer_id: officer.id
            }
          }
        end

        before { officer }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_category: { type: :object }
                   },
                   required: ['idea_category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:existing_category) do
          Idea::Category.create!(
            name: 'Original Category'
          )
        end
        let(:id) { existing_category.id }
        let(:idea_category) do
          {
            idea_category: {
              name: 'Forbidden Update'
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

      response '422', 'invalid request' do
        let(:existing_category) do
          Idea::Category.create!(
            name: 'Original Category'
          )
        end
        let(:id) { existing_category.id }
        let(:idea_category) do
          {
            idea_category: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(Idea::Category).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name can\'t be blank'])
          allow_any_instance_of(Idea::Category).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete an idea category' do
      tags 'Idea Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete an idea category. Categories with associated ideas cannot be deleted. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '204', 'idea category deleted' do
        let(:category) do
          Idea::Category.create!(
            name: 'Category to Delete'
          )
        end
        let(:id) { category.id }

        run_test!
      end

      response '422', 'cannot delete category with associated ideas' do
        let(:category) do
          cat = Idea::Category.create!(
            name: 'Category with Ideas'
          )
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            idea_category_id: cat.id,
            title: 'Test Idea',
            description: 'Test Description'
          )
          idea.save!
          cat
        end
        let(:id) { category.id }

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
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:category) do
          Idea::Category.create!(
            name: 'Category to Delete'
          )
        end
        let(:id) { category.id }

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

      response '404', 'idea category not found' do
        let(:id) { 999999 }
        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end
