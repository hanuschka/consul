# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Ideas API', type: :request, openapi_spec: 'v1/swagger.yaml' do
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
    category = Idea::Category.create!(name: 'Test Category') if defined?(Idea::Category)
    [user, category]
  end

  path '/api/ideas' do
    get 'List ideas' do
      tags 'Ideas'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retrieve a paginated list of citizen ideas and proposals. Ideas are user-submitted suggestions for community improvements that may have been reviewed and accepted by administrators. Supports both admin and public_data access levels.'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of ideas per page (default: 100, max: 500)'

      response '200', 'ideas found and returned' do
        before do
          _user, _category = create_minimal_prereqs
          2.times do |i|
            idea = Idea.new(
              author: api_client.user,
              resource_terms: true,
              admin_accepted_at: Time.current,
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Idea #{i+1}",
                  description: "Description #{i+1}"
                }
              ]
            )
            idea.save!
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

      response '403', 'forbidden - insufficient access' do
        before do
          # Create a client without proper access level by bypassing validation
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

      response '200', 'ideas found with public_data access' do
        before do
          api_client.update!(access_level: :public_data)
          _user, _category = create_minimal_prereqs
          2.times do |i|
            idea = Idea.new(
              author: api_client.user,
              resource_terms: true,
              admin_accepted_at: Time.current,
              translations_attributes: [
                {
                  locale: 'en',
                  title: "Idea #{i+1}",
                  description: "Description #{i+1}"
                }
              ]
            )
            idea.save!
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
      description 'Submit a new citizen idea for community improvement. Ideas go through an admin review process before being published. Supports categorization, video attachments, location mapping, image attachments, and optional on-behalf-of attribution. Requires acceptance of terms and conditions.'

      parameter name: :idea, in: :body, description: 'Idea submission with required title/description and optional category, location, video, image, and behalf-of information', schema: {
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
              image_attributes: {
                type: :object,
                description: 'Optional: Image to illustrate the idea (photo, diagram, visualization, etc.). Upload as base64-encoded data. Recommended for presenting visual evidence or demonstrating the idea concept.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
                  title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image. Helps visually-impaired users understand the image content.' },
                  credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information. Displayed with the image to give proper credit.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the idea. Does not affect other idea properties.' }
                }
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

      response '201', 'idea created with base64 image' do
        let(:idea) do
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            idea: {
              title: 'New Idea',
              description: 'A meaningful description',
              resource_terms: true,
              image_attributes: {
                attachment: base64_png,
                title: 'Idea Cover Image'
              },
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['idea']).to be_present
          expect(response.status).to eq(201)
        end
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
        let(:idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Test Idea',
                description: 'Test Description'
              }
            ]
          )
          idea.save!
          idea
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

      response '403', 'forbidden - insufficient access' do
        let(:idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Test Idea',
                description: 'Test Description'
              }
            ]
          )
          idea.save!
          idea
        end
        let(:id) { idea.id }
        before do
          idea # Ensure idea is created before the request
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
    end

    patch 'Update an idea' do
      tags 'Ideas'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Update an existing idea with new content, category, location, video, or image. Can add, replace, or remove the idea image. All fields are optional - only provide fields to change. Requires admin access.'

      parameter name: :idea, in: :body, description: 'Idea attributes to update (title, description, category, video_url, image, translations). Any field not provided remains unchanged.', schema: {
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
              image_attributes: {
                type: :object,
                description: 'Update, replace, or remove the idea image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove. All fields are optional.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file to replace current image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB). Omit to keep existing image.' },
                  title: { type: :string, nullable: true, description: 'Updated image caption or alt text. Improves accessibility by describing the image content for screen readers.' },
                  credits: { type: :string, nullable: true, description: 'Updated image source attribution, photographer/artist name, or copyright notice. Properly credits original creators.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image entirely from the idea while preserving the idea text and other properties.' }
                }
              },
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
        let(:existing_idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Idea',
                description: 'Original Description'
              }
            ]
          )
          idea.save!
          idea
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:existing_idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Idea',
                description: 'Original Description'
              }
            ]
          )
          idea.save!
          idea
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
        let(:existing_idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Idea',
                description: 'Original Description'
              }
            ]
          )
          idea.save!
          idea
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

      response '200', 'idea updated with base64 image' do
        let(:existing_idea) do
          idea = Idea.new(
            author: api_client.user,
            resource_terms: true,
            admin_accepted_at: Time.current,
            translations_attributes: [
              {
                locale: 'en',
                title: 'Original Idea',
                description: 'Original Description'
              }
            ]
          )
          idea.save!
          idea
        end
        let(:id) { existing_idea.id }
        let(:idea) do
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            idea: {
              description: 'Updated description',
              image_attributes: {
                attachment: base64_png,
                title: 'Updated Idea Image'
              }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['idea']).to be_present
          expect(response.status).to eq(200)
        end
      end

    end
  end
end

