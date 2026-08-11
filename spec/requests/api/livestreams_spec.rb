# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Livestreams API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_livestream_phase) { create_projekt_phase('ProjektPhase::LivestreamPhase') }
let(:existing_projekt_livestream) do
  existing_livestream_phase.projekt_livestreams.create!(
    url: 'https://example.com/existing_livestream',
    title: 'Existing Livestream',
    video_platform: 'youtube'
  )
end

  PROJEKT_LIVESTREAM_PARAMS = {
    type: :object,
    properties: {
      url: {
        type: :string,
        nullable: true,
        description: 'The URL where the livestream will be broadcast',
        example: 'https://youtube.com/live/ABC123'
      },
      title: {
        type: :string,
        nullable: true,
        description: 'The title or name of the livestream event',
        example: 'Community Town Hall Discussion'
      },
      description: {
        type: :string,
        nullable: true,
        description: 'Description of the livestream content and agenda',
        example: 'Live discussion with city officials on budget priorities'
      },
      starts_at: {
        type: :string,
        format: :date_time,
        nullable: true,
        description: 'When the livestream is scheduled to start',
        example: '2024-02-01T18:00:00Z'
      }
    }
  }.freeze

  PROJEKT_LIVESTREAM_PARAM_SCHEMA = {
    type: :object,
    properties: {
      projekt_livestream: PROJEKT_LIVESTREAM_PARAMS
    },
    required: ['projekt_livestream']
  }.freeze

  path '/api/projekt_phases/{projekt_phase_id}/livestreams' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LivestreamPhase)'

    get 'List projekt livestreams for a projekt phase' do
      tags 'Livestreams'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all livestream events scheduled for a projekt phase. Livestreams are real-time video broadcasts used for Q&A sessions, town halls, and participation events. Includes video platform information and streaming URLs.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt livestreams found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_phase_id) { livestream_phase.id }

        before do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream1',
            title: 'Livestream 1',
            video_platform: 'youtube'
          )
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream2',
            title: 'Livestream 2',
            video_platform: 'youtube'
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_livestreams: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['projekt_livestreams']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt livestream' do
      tags 'Livestreams'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Schedule a new livestream event for a projekt phase. Livestreams support multiple video platforms (YouTube, Vimeo, etc.) and can include scheduled start/end times. Participants can submit questions during livestreams. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_livestream, in: :body, description: 'Livestream details with URL, title, and optional scheduling information', schema: PROJEKT_LIVESTREAM_PARAM_SCHEMA

      response '201', 'projekt livestream created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_phase_id) { livestream_phase.id }
        let(:projekt_livestream) do
          {
            projekt_livestream: {
              url: 'https://example.com/livestream',
              title: 'Test Livestream',
              description: 'Test description',
              starts_at: '2025-01-01T12:00:00Z'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_livestream: { type: :object }
                   },
                   required: ['projekt_livestream']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_phase_id) { livestream_phase.id }
        let(:projekt_livestream) do
          {
            projekt_livestream: {
              url: 'invalid_url',
              starts_at: 'invalid_date'
            }
          }
        end

        before do
          allow_any_instance_of(ProjektLivestream).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['URL is invalid'])
          allow_any_instance_of(ProjektLivestream).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:projekt_phase_id) { 1 } }
      forbidden_response { let(:projekt_phase_id) { existing_livestream_phase.id } }
    end
  end

  path '/api/livestreams' do
    get 'List all projekt livestreams' do
      tags 'Livestreams'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all livestreams across all projekt phases.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt livestreams found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:livestream_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:livestream_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }

        before do
          livestream_phase1.projekt_livestreams.create!(
            url: 'https://example.com/livestream1',
            title: 'Livestream 1',
            video_platform: 'youtube'
          )
          livestream_phase2.projekt_livestreams.create!(
            url: 'https://example.com/livestream2',
            title: 'Livestream 2',
            video_platform: 'youtube'
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_livestreams: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['projekt_livestreams']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/livestreams/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Livestream ID'

    get 'Retrieve a projekt livestream' do
      tags 'Livestreams'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single livestream by ID.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt livestream found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_livestream) do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream',
            title: 'Test Livestream',
            video_platform: 'youtube'
          )
        end
        let(:id) { projekt_livestream.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_livestream: { type: :object }
                   },
                   required: ['projekt_livestream']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt livestream not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt livestream' do
      tags 'Livestreams'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt livestream. Allows modifying livestream URL, title, description, and scheduled time. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_livestream, in: :body, description: 'Attributes to update on the projekt livestream', schema: PROJEKT_LIVESTREAM_PARAM_SCHEMA

      response '200', 'projekt livestream updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:test_projekt_livestream) do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream',
            title: 'Original Title',
            video_platform: 'youtube'
          )
        end
        let(:id) { test_projekt_livestream.id }
        let(:projekt_livestream) do
          {
            projekt_livestream: {
              title: 'Updated Title',
              description: 'Updated description'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_livestream: { type: :object }
                   },
                   required: ['projekt_livestream']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt livestream not found' do
        let(:id) { 999999 }
        let(:projekt_livestream) do
          {
            projekt_livestream: {
              title: 'Updated Title'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:test_projekt_livestream) do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream',
            title: 'Original Title',
            video_platform: 'youtube'
          )
        end
        let(:id) { test_projekt_livestream.id }
        let(:projekt_livestream) do
          {
            projekt_livestream: {
              starts_at: 'invalid_date'
            }
          }
        end

        before do
          allow_any_instance_of(ProjektLivestream).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Starts at is invalid'])
          allow_any_instance_of(ProjektLivestream).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:id) { existing_projekt_livestream.id } }
    end

    delete 'Delete a projekt livestream' do
      tags 'Livestreams'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt livestream. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt livestream deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_livestream) do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream',
            title: 'Livestream To Delete',
            video_platform: 'youtube'
          )
        end
        let(:id) { projekt_livestream.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt livestream not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt livestream' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:projekt_livestream) do
          livestream_phase.projekt_livestreams.create!(
            url: 'https://example.com/livestream',
            title: 'Livestream',
            video_platform: 'youtube'
          )
        end
        let(:id) { projekt_livestream.id }

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
          allow_any_instance_of(ProjektLivestream).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt livestream'] })
          allow_any_instance_of(ProjektLivestream).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_livestream.id } }
    end
  end
end
