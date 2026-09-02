# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Arguments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  let(:existing_argument_phase) do
    Projekt.create!(name: 'Projekt').projekt_phases.create!(
      type: 'ProjektPhase::ArgumentPhase', active: true
    )
  end
  let(:existing_projekt_argument) do
    existing_argument_phase.projekt_arguments.create!(
      name: 'Existing Argument', position: 1, note: 'Existing note', pro: true
    )
  end

  IMAGE_ATTRIBUTES_SCHEMA = {
    type: :object,
    description: 'Optional: Image to support the argument (infographic, chart, diagram, evidence photo, etc.). Upload as base64-encoded data. Recommended for presenting visual evidence or data supporting the argument position.',
    properties: {
      attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
      title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image. Helps visually-impaired users understand the image content.' },
      credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information. Displayed with the image to give proper credit.' },
      ai_generated: { type: :boolean, nullable: true, description: 'Set to true when the image was created or edited with AI; the public page then shows the AI disclosure label' },
      _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the argument. Does not affect other argument properties.' }
    }
  }.freeze

  PROJEKT_ARGUMENT_PARAMS = {
    type: :object,
    properties: {
      name: { type: :string, nullable: true, description: 'Argument title or name. Optional, can be auto-generated if not provided.' },
      position: { type: :integer, nullable: true, description: 'Display order among other arguments in the phase. Lower numbers appear first.' },
      note: { type: :string, nullable: true, description: 'Detailed argument text explaining the position, evidence, and reasoning.' },
      pro: { type: :boolean, nullable: true, description: 'true = pro-argument (in favor), false/null = con-argument (against)' },
      image_attributes: IMAGE_ATTRIBUTES_SCHEMA
    }
  }.freeze

  PROJEKT_ARGUMENT_PARAM_SCHEMA = {
    type: :object,
    properties: {
      projekt_argument: PROJEKT_ARGUMENT_PARAMS
    },
    required: ['projekt_argument']
  }.freeze

  path '/api/projekt_phases/{projekt_phase_id}/arguments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (ArgumentPhase)'

    get 'List projekt arguments by phase' do
      tags 'Arguments'
      produces 'application/json'
      security [bearer_auth: []]
      description "List all arguments (pro and con) for a specific projekt phase. Supports pagination for efficient loading of large argument sets. Arguments are ordered by creation date with pagination support. #{ApiAccessRequirements::GET_READ_ONLY}"

      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number for pagination (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** depends on configuration)'

      response '200', 'projekt arguments list returned successfully' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let!(:pro_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Pro Argument',
            position: 1,
            note: 'This is a pro argument',
            pro: true
          )
        end
        let!(:con_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Con Argument',
            position: 2,
            note: 'This is a con argument',
            pro: false
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     arguments: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['arguments']
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

        run_test!
      end

      response '404', 'projekt phase not found' do
        let(:projekt_phase_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt argument' do
      tags 'Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new argument (pro or con) for a projekt phase. Arguments present reasoning, evidence, or positions on a topic within the ArgumentPhase. Can include supporting images with titles and credits. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_argument, in: :body, description: 'Argument details with optional name, position, note, pro/con flag, and image attachment', schema: PROJEKT_ARGUMENT_PARAM_SCHEMA

      response '201', 'projekt argument created successfully' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Test Argument',
              position: 1,
              note: 'Test note',
              pro: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektArgument).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
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

      response '422', 'projekt argument with unsupported image content type returns validation error' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Argument with Unsupported Image',
              position: 1,
              note: 'Test argument with unsupported image content type',
              pro: true,
              image_attributes: {
                attachment: 'data:application/pdf;base64,SGVsbG8=',
                title: 'Unsupported Image',
                credits: 'Test'
              }
            }
          }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
          expect(response.status).to eq(422)
        end
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { existing_argument_phase.id } }
    end
  end

  path '/api/arguments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Argument ID'

    get 'Retrieve a projekt argument' do
      tags 'Arguments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single argument by ID with all its details. Returns the argument text, pro/con classification, display position, and any associated image with metadata. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt argument found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Test Argument',
            position: 1,
            note: 'Test note',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt argument' do
      tags 'Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing argument with new content, positioning, or pro/con classification. Can also add, replace, or remove the supporting image. All fields are optional - only provide fields to change. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_argument, in: :body, description: 'Argument attributes to update (name, position, note, pro/con flag, image). Any field not provided remains unchanged.', schema: PROJEKT_ARGUMENT_PARAM_SCHEMA

      response '200', 'projekt argument updated successfully' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:test_projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Original Argument',
            position: 1,
            note: 'Original note',
            pro: true
          )
        end
        let(:id) { test_projekt_argument.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Updated Argument',
              note: 'Updated note'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_argument: { type: :object }
                   },
                   required: ['projekt_argument']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Updated Argument'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:test_projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Original Argument',
            position: 1,
            pro: true
          )
        end
        let(:id) { test_projekt_argument.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektArgument).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
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

      response '422', 'projekt argument update with unsupported image content type returns validation error' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:test_projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Original Argument',
            position: 1,
            note: 'Original note',
            pro: true
          )
        end
        let(:id) { test_projekt_argument.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Updated Argument',
              note: 'Updated note',
              image_attributes: {
                attachment: 'data:application/pdf;base64,SGVsbG8=',
                title: 'Unsupported Updated Image',
                credits: 'Test'
              }
            }
          }
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']).to be_present
          expect(response.status).to eq(422)
        end
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_argument.id } }
    end

    delete 'Delete a projekt argument' do
      tags 'Arguments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete an argument and all associated data (including any attached images). This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt argument deleted successfully' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Argument To Delete',
            position: 1,
            note: 'Note to delete',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt argument not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt argument' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_argument) do
          argument_phase.projekt_arguments.create!(
            name: 'Argument',
            position: 1,
            note: 'Test note',
            pro: true
          )
        end
        let(:id) { projekt_argument.id }

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
          allow_any_instance_of(ProjektArgument).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt argument'] })
          allow_any_instance_of(ProjektArgument).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_argument.id } }
    end
  end
end
