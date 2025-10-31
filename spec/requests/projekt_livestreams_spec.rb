# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Livestreams API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/projekt_livestreams' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LivestreamPhase)'

    post 'Create a projekt livestream' do
      tags 'Projekt Livestreams'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_livestream, in: :body, description: 'Projekt livestream creation payload', schema: {
        type: :object,
        properties: {
          projekt_livestream: {
            type: :object,
            properties: {
              url: { type: :string, nullable: true },
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              starts_at: { type: :string, format: :date_time, nullable: true },
              video_platform: { type: :string, nullable: true },
              external_id: { type: :string, nullable: true },
              preview_image_url: { type: :string, nullable: true }
            }
          }
        },
        required: ['projekt_livestream']
      }

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
              starts_at: '2025-01-01T12:00:00Z',
              video_platform: 'youtube',
              external_id: 'abc123'
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
    end
  end

  path '/api/projekt_livestreams/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Livestream ID'

    get 'Retrieve a projekt livestream' do
      tags 'Projekt Livestreams'
      produces 'application/json'
      security [bearer_auth: []]

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
    end

    patch 'Update a projekt livestream' do
      tags 'Projekt Livestreams'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_livestream, in: :body, description: 'Attributes to update on the projekt livestream', schema: {
        type: :object,
        properties: {
          projekt_livestream: {
            type: :object,
            properties: {
              url: { type: :string, nullable: true },
              title: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              starts_at: { type: :string, format: :date_time, nullable: true },
              video_platform: { type: :string, nullable: true },
              external_id: { type: :string, nullable: true },
              preview_image_url: { type: :string, nullable: true }
            }
          }
        },
        required: ['projekt_livestream']
      }

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
    end

    delete 'Delete a projekt livestream' do
      tags 'Projekt Livestreams'
      produces 'application/json'
      security [bearer_auth: []]

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
    end
  end
end
