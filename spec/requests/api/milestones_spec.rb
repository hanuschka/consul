# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestones API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/milestones' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID'

    get 'List all milestones' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retrieve all milestones for a projekt phase. Milestones track project progress over time and include status updates. Each milestone spans a date range and contains status information about completed activities.'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (default: 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of milestones per page (default: 100, max: 500)'

      response '200', 'milestones found and returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestones: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['milestones']
                 },
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   }
                 }
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }

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
    end

    post 'Create a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Create a new milestone in a projekt phase milestone timeline. Milestones mark important dates and include status updates. Required fields: publication_date and status_id. Supports optional image attachments for visual representation of milestone progress. Requires admin access.'

      parameter name: :milestone, in: :body, description: 'Milestone creation with required publication date and status, and optional image attachment', schema: {
        type: :object,
        properties: {
          milestone: {
            type: :object,
            properties: {
              publication_date: { type: :string, format: :date },
              status_id: { type: :integer },
              image_attributes: {
                type: :object,
                description: 'Optional: Image to represent the milestone (progress photo, status visualization, etc.). Upload as base64-encoded data.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
                  title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image.' },
                  credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the milestone.' }
                }
              }
            }
          }
        },
        required: ['milestone']
      }

      response '201', 'milestone created' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s,
              status_id: 1
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
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

        before do
          allow_any_instance_of(Milestone).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Invalid milestone'])
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
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

      response '201', 'milestone created with base64 image' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase_id) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt).id }
        let(:milestone) do
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            milestone: {
              publication_date: Date.today.to_s,
              status_id: 1,
              image_attributes: {
                attachment: base64_png,
                title: 'Milestone Progress Image'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestone']).to be_present
          expect(response.status).to eq(201)
        end
      end
    end
  end

  path '/api/milestones/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Milestone ID'

    get 'Retrieve a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'milestone found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
    end

    patch 'Update a milestone' do
      tags 'Milestones'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Update an existing milestone with new dates, status, or image. Can add, replace, or remove the milestone image. All fields are optional - only provide fields to change. Requires admin access.'

      parameter name: :milestone, in: :body, description: 'Milestone attributes to update (publication_date, status_id, image). Any field not provided remains unchanged.', schema: {
        type: :object,
        properties: {
          milestone: {
            type: :object,
            properties: {
              publication_date: { type: :string, format: :date },
              status_id: { type: :integer },
              image_attributes: {
                type: :object,
                description: 'Update, replace, or remove the milestone image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove. All fields are optional.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file to replace current image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB). Omit to keep existing image.' },
                  title: { type: :string, nullable: true, description: 'Updated image caption or alt text. Improves accessibility by describing the image content.' },
                  credits: { type: :string, nullable: true, description: 'Updated image source attribution, photographer/artist name, or copyright notice.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image entirely from the milestone while preserving other milestone properties.' }
                }
              }
            }
          }
        },
        required: ['milestone']
      }

      response '200', 'milestone updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }
        let(:milestone) do
          {
            milestone: {
              publication_date: Date.today.to_s
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
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

        before do
          allow_any_instance_of(Milestone).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Update failed'])
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          {
            milestone: {
              publication_date: (Date.today + 1).to_s
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

      response '200', 'milestone updated with base64 image' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }
        let(:milestone) do
          base64_png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=='
          {
            milestone: {
              publication_date: (Date.today + 1).to_s,
              image_attributes: {
                attachment: base64_png,
                title: 'Updated Milestone Image'
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone: { type: :object }
                   },
                   required: ['milestone']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['milestone']).to be_present
          expect(response.status).to eq(200)
        end
      end
    end

    delete 'Delete a milestone' do
      tags 'Milestones'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'milestone deleted' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'milestone not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete milestone' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete milestone'] })

          allow_any_instance_of(Milestone).to receive(:destroy).and_return(false)
          allow_any_instance_of(Milestone).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::MilestonePhase.create!(projekt: test_projekt) }
        let(:test_milestone) { Milestone.create!(milestoneable: projekt_phase, publication_date: Date.today, description_en: 'Test milestone') }
        let(:id) { test_milestone.id }

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
