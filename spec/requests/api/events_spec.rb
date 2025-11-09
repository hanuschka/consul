# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Events API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/events' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (EventPhase)'

    get 'List projekt events for a projekt phase' do
      tags 'Events'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all events scheduled for a specific projekt phase. Events are public meetings, webinars, or participation activities scheduled as part of the project engagement. Returns paginated results with event details (time, location, registration link).#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (default: 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of events per page (default: 100, max: 500)', required: false

      response '200', 'projekt events found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:event_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::EventPhase', active: true) }
        let(:projekt_phase_id) { event_phase.id }

        before do
          event_phase.projekt_events.create!(title: 'Event 1', datetime: '2025-02-01T18:00:00Z')
          event_phase.projekt_events.create!(title: 'Event 2', datetime: '2025-02-02T18:00:00Z')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     events: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektEvent' }
                     }
                   },
                   required: ['events']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a projekt event' do
      tags 'Events'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Schedule a new event for a projekt phase. Events can be in-person meetings (with location), online webinars (with registration URL), or open-ended events. Required: event title. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_event, in: :body, description: 'Event details with required title and optional datetime, location, and registration URL', schema: {
        type: :object,
        properties: {
          projekt_event: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string, nullable: true },
              summary: { type: :string, nullable: true },
              datetime: { type: :string, format: :date_time, nullable: true },
              end_datetime: { type: :string, format: :date_time, nullable: true },
              location: { type: :string, nullable: true },
              weblink: { type: :string, nullable: true },
              open_ended: { type: :boolean, nullable: true }
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
      tags 'Events'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single event by ID.#{ApiAccessRequirements::GET_READ_ONLY}"

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
      tags 'Events'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt event. Allows modifying event details such as title, description, datetime, location, and weblink. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_event, in: :body, description: 'Attributes to update on the event', schema: {
        type: :object,
        properties: {
          projekt_event: {
            type: :object,
            properties: {
              title: { type: :string },
              description: { type: :string, nullable: true },
              summary: { type: :string, nullable: true },
              datetime: { type: :string, format: :date_time, nullable: true },
              end_datetime: { type: :string, format: :date_time, nullable: true },
              location: { type: :string, nullable: true },
              weblink: { type: :string, nullable: true },
              open_ended: { type: :boolean, nullable: true }
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
      tags 'Events'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt event. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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


