# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Events API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/events' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (EventPhase)'

    post 'Create a projekt event' do
      tags 'Projekt Events'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_event, in: :body, description: 'Projekt Event creation payload', schema: {
        type: :object,
        properties: {
          projekt_event: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string, nullable: true },
              datetime: { type: :string, format: :date_time, nullable: true },
              end_datetime: { type: :string, format: :date_time, nullable: true },
              location: { type: :string, nullable: true },
              registration_url: { type: :string, nullable: true }
            },
            required: ['title']
          }
        },
        required: ['projekt_event']
      }

      response '201', 'projekt event created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:projekt_phase_id) { event_phase.id }
        let(:projekt_event) do
          { projekt_event: { title: 'Town Hall', datetime: '2025-02-01T18:00:00Z' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_event: { '$ref' => '#/components/schemas/ProjektEvent' }
                   },
                   required: ['projekt_event']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:projekt_phase_id) { event_phase.id }
        let(:projekt_event) do
          { projekt_event: { title: '' } }
        end

        before do
          allow_any_instance_of(ProjektEvent).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title is invalid'])
          allow_any_instance_of(ProjektEvent).to receive(:errors).and_return(errors_mock)
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

  path '/api/events/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Event ID'

    get 'Retrieve a projekt event' do
      tags 'Projekt Events'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt event found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:created_event) { event_phase.projekt_events.create!(title: 'Town Hall', datetime: '2025-02-01T18:00:00Z') }
        let(:id) { created_event.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_event: { '$ref' => '#/components/schemas/ProjektEvent' }
                   },
                   required: ['projekt_event']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt event not found' do
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update a projekt event' do
      tags 'Projekt Events'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_event, in: :body, description: 'Attributes to update on the event', schema: {
        type: :object,
        properties: {
          projekt_event: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string, nullable: true },
              datetime: { type: :string, format: :date_time, nullable: true },
              end_datetime: { type: :string, format: :date_time, nullable: true },
              location: { type: :string, nullable: true },
              registration_url: { type: :string, nullable: true }
            }
          }
        }
      }

      response '200', 'projekt event updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:created_event) { event_phase.projekt_events.create!(title: 'Town Hall', datetime: '2025-02-01T18:00:00Z') }
        let(:id) { created_event.id }
        let(:projekt_event) do
          { projekt_event: { description: 'Updated description' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_event: { '$ref' => '#/components/schemas/ProjektEvent' }
                   },
                   required: ['projekt_event']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:created_event) { event_phase.projekt_events.create!(title: 'Town Hall', datetime: '2025-02-01T18:00:00Z') }
        let(:id) { created_event.id }
        let(:projekt_event) do
          { projekt_event: { datetime: 'invalid' } }
        end

        before do
          allow_any_instance_of(ProjektEvent).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Datetime is invalid'])
          allow_any_instance_of(ProjektEvent).to receive(:errors).and_return(errors_mock)
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

    delete 'Delete a projekt event' do
      tags 'Projekt Events'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt event deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:created_event) { event_phase.projekt_events.create!(title: 'Town Hall', datetime: '2025-02-01T18:00:00Z') }
        let(:id) { created_event.id }

        schema type: :object,
               properties: { message: { type: :string } },
               required: ['message']

        run_test!
      end

      response '422', 'unable to delete projekt event' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:created_event) { event_phase.projekt_events.create!(title: 'Town Hall', datetime: '2025-02-01T18:00:00Z') }
        let(:id) { created_event.id }

        before do
          allow_any_instance_of(ProjektEvent).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete event'] })
          allow_any_instance_of(ProjektEvent).to receive(:errors).and_return(errors_mock)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        run_test!
      end
    end
  end
end


