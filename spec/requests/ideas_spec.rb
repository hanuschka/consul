# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Ideas API', type: :request, openapi_spec: 'v1/swagger.yaml' do
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
    category = Idea::Category.create!(name: 'Test Category') if defined?(Idea::Category)
    [user, category]
  end

  path '/api/ideas' do
    get 'List ideas' do
      tags 'Ideas'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'

      response '200', 'ideas found' do
        before do
          user, = create_minimal_prereqs
          2.times do |i|
            idea = Idea.create!(
              author: user,
              title: "Idea #{i+1}",
              description: "Description #{i+1}",
              resource_terms: true,
              admin_accepted_at: Time.current
            )
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     ideas: { type: :array, items: { type: :object } }
                   },
                   required: ['ideas']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create an idea' do
      tags 'Ideas'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :idea, in: :body, description: 'Idea payload', schema: {
        type: :object,
        properties: {
          idea: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string },
              video_url: { type: :string, nullable: true },
              on_behalf_of: { type: :string, nullable: true },
              idea_category_id: { type: :integer, nullable: true },
              resource_terms: { type: :boolean },
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
              }
            },
            required: %w[title description resource_terms]
          }
        },
        required: ['idea']
      }

      response '201', 'idea created' do
        let(:user) { User.create!(username: 'testuser', email: 'test@example.com', password: 'Password1!', terms_data_storage: '1', terms_data_protection: '1', terms_general: '1') }

        before do
          api_client.update(user: user)
        end

        let(:idea) do
          {
            idea: {
              title: 'New Idea',
              description: 'A meaningful description',
              resource_terms: true,
              translations_attributes: [
                {
                  locale: 'en',
                  title: 'New Idea',
                  description: 'A meaningful description'
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
                     idea: { type: :object }
                   },
                   required: ['idea']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:idea) do
          {
            idea: {
              title: '',
              description: ''
            }
          }
        end

        before do
          allow_any_instance_of(Idea).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(Idea).to receive(:errors).and_return(errors_mock)
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

  path '/api/ideas/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Idea ID'

    get 'Retrieve an idea' do
      tags 'Ideas'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'idea found' do
        let(:user) { User.create!(username: 'testuser', email: 'test@example.com', password: 'Password1!', terms_data_storage: '1', terms_data_protection: '1', terms_general: '1') }
        let(:idea) do
          Idea.create!(
            author: user,
            title: 'Test Idea',
            description: 'Test Description',
            resource_terms: true,
            admin_accepted_at: Time.current
          )
        end
        let(:id) { idea.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea: { type: :object }
                   },
                   required: ['idea']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'idea not found' do
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update an idea' do
      tags 'Ideas'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :idea, in: :body, description: 'Attributes to update on the idea', schema: {
        type: :object,
        properties: {
          idea: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              video_url: { type: :string, nullable: true },
              on_behalf_of: { type: :string, nullable: true },
              idea_category_id: { type: :integer, nullable: true },
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
              }
            }
          }
        }
      }

      response '200', 'idea updated' do
        let(:user) { User.create!(username: 'testuser', email: 'test@example.com', password: 'Password1!', terms_data_storage: '1', terms_data_protection: '1', terms_general: '1') }
        let(:existing_idea) do
          Idea.create!(
            author: user,
            title: 'Original Idea',
            description: 'Original Description',
            resource_terms: true,
            admin_accepted_at: Time.current
          )
        end
        let(:id) { existing_idea.id }
        let(:idea) do
          {
            idea: {
              description: 'Updated description'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea: { type: :object }
                   },
                   required: ['idea']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:user) { User.create!(username: 'testuser', email: 'test@example.com', password: 'Password1!', terms_data_storage: '1', terms_data_protection: '1', terms_general: '1') }
        let(:existing_idea) do
          Idea.create!(
            author: user,
            title: 'Original Idea',
            description: 'Original Description',
            resource_terms: true,
            admin_accepted_at: Time.current
          )
        end
        let(:id) { existing_idea.id }
        let(:idea) do
          {
            idea: {
              title: ''
            }
          }
        end

        before do
          allow_any_instance_of(Idea).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title can\'t be blank'])
          allow_any_instance_of(Idea).to receive(:errors).and_return(errors_mock)
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

