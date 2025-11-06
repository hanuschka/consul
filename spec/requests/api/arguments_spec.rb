# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Arguments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/arguments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (ArgumentPhase)'

    post 'Create a projekt argument' do
      tags 'Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Create a new argument (pro or con) for a projekt phase. Arguments present reasoning, evidence, or positions on a topic within the ArgumentPhase. Can include supporting images with titles and credits. Requires admin access.'

      parameter name: :projekt_argument, in: :body, description: 'Argument details with optional name, position, note, pro/con flag, and image attachment', schema: {
        type: :object,
        properties: {
          projekt_argument: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true, description: 'Argument title or name. Optional, can be auto-generated if not provided.' },
              position: { type: :integer, nullable: true, description: 'Display order among other arguments in the phase. Lower numbers appear first.' },
              note: { type: :string, nullable: true, description: 'Detailed argument text explaining the position, evidence, and reasoning.' },
              pro: { type: :boolean, nullable: true, description: 'true = pro-argument (in favor), false/null = con-argument (against)' },
              image_attributes: {
                type: :object,
                description: 'Optional: Image to support the argument (infographic, chart, diagram, evidence photo, etc.). Upload as base64-encoded data. Recommended for presenting visual evidence or data supporting the argument position.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file. Required when adding a new image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB for optimal performance).' },
                  title: { type: :string, nullable: true, description: 'Image caption, alt text, or brief description. Used for accessibility and displayed with the image. Helps visually-impaired users understand the image content.' },
                  credits: { type: :string, nullable: true, description: 'Image source attribution, photographer/artist name, or copyright information. Displayed with the image to give proper credit.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current image from the argument. Does not affect other argument properties.' }
                }
              }
            }
          }
        },
        required: ['projekt_argument']
      }

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

      response '422', 'projekt argument with invalid image returns validation error' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:argument_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ArgumentPhase', active: true) }
        let(:projekt_phase_id) { argument_phase.id }
        let(:projekt_argument) do
          {
            projekt_argument: {
              name: 'Argument with Invalid Image',
              position: 1,
              note: 'Test argument with invalid image',
              pro: true,
              image_attributes: {
                attachment: 'invalid-base64-data',
                title: 'Invalid Image',
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
    end
  end

  path '/api/arguments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Argument ID'

    get 'Retrieve a projekt argument' do
      tags 'Arguments'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Retrieve a single argument by ID with all its details. Returns the argument text, pro/con classification, display position, and any associated image with metadata.'

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
    end

    patch 'Update a projekt argument' do
      tags 'Arguments'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Update an existing argument with new content, positioning, or pro/con classification. Can also add, replace, or remove the supporting image. All fields are optional - only provide fields to change. Requires admin access.'

      parameter name: :projekt_argument, in: :body, description: 'Argument attributes to update (name, position, note, pro/con flag, image). Any field not provided remains unchanged.', schema: {
        type: :object,
        properties: {
          projekt_argument: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true, description: 'Updated argument title or name' },
              position: { type: :integer, nullable: true, description: 'New display order among arguments' },
              note: { type: :string, nullable: true, description: 'Updated argument text/evidence/reasoning' },
              pro: { type: :boolean, nullable: true, description: 'true = pro-argument, false/null = con-argument' },
              image_attributes: {
                type: :object,
                description: 'Update, replace, or remove the supporting image. Attach a new image (base64-encoded), update metadata (title/credits), or set _destroy=true to remove. All fields are optional.',
                properties: {
                  attachment: { type: :string, nullable: true, description: 'Base64-encoded image file to replace current image. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB). Omit to keep existing image.' },
                  title: { type: :string, nullable: true, description: 'Updated image caption or alt text. Improves accessibility by describing the image content for screen readers and improving discoverability.' },
                  credits: { type: :string, nullable: true, description: 'Updated image source attribution, photographer/artist name, or copyright notice. Properly credits original creators.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the image entirely from the argument while preserving the argument text and other properties.' }
                }
              }
            }
          }
        },
        required: ['projekt_argument']
      }

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

      response '422', 'projekt argument update with invalid image returns validation error' do
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
                attachment: 'invalid-base64-data',
                title: 'Invalid Updated Image',
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
    end

    delete 'Delete a projekt argument' do
      tags 'Arguments'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Delete an argument and all associated data (including any attached images). Only admin users can delete arguments. This action is permanent and cannot be undone.'

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
    end
  end
end
