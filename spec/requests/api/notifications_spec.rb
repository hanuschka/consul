# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Notifications API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_notification_phase) { create_projekt_phase('ProjektPhase::ProjektNotificationPhase') }
let(:existing_projekt_notification) do
  existing_notification_phase.projekt_notifications.create!(
    title: 'Existing Notification', body: 'Existing body'
  )
end

  path '/api/projekt_phases/{projekt_phase_id}/notifications' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (ProjektNotificationPhase)'

    get 'List projekt notifications for a projekt phase' do
      tags 'Notifications'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all notifications for a projekt phase. Notifications are messages sent to participants with updates, announcements, or calls to action. Can include links for directing users to relevant pages. Returns paginated results.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt notifications found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:projekt_phase_id) { notif_phase.id }

        before do
          notif_phase.projekt_notifications.create!(title: 'Notification 1', body: 'Body 1')
          notif_phase.projekt_notifications.create!(title: 'Notification 2', body: 'Body 2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     notifications: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektNotification' }
                     }
                   },
                   required: ['notifications']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt notification' do
      tags 'Notifications'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Send a notification to projekt participants. Notifications are announcements and updates that can include call-to-action links. Supports segment-based targeting (e.g., \"all\", specific groups). Required: notification title. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_notification, in: :body, description: 'Notification with required title and optional body, link, and recipient segment', schema: {
        type: :object,
        properties: {
          projekt_notification: {
            type: :object,
            properties: {
              title: { type: :string },
              body: { type: :string, nullable: true },
              link_text: { type: :string, nullable: true },
              link_url: { type: :string, nullable: true },
              segment_recipient: { type: :string, nullable: true }
            },
            required: ['title']
          }
        },
        required: ['projekt_notification']
      }

      response '201', 'projekt notification created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:projekt_phase_id) { notif_phase.id }
        let(:projekt_notification) do
          { projekt_notification: { title: 'Update', body: 'We have news' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_notification: { '$ref' => '#/components/schemas/ProjektNotification' }
                   },
                   required: ['projekt_notification']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:projekt_phase_id) { notif_phase.id }
        let(:projekt_notification) do
          { projekt_notification: { title: '' } }
        end

        before do
          allow_any_instance_of(ProjektNotification).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title is invalid'])
          allow_any_instance_of(ProjektNotification).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:projekt_phase_id) { existing_notification_phase.id } }
    end
  end

  path '/api/notifications' do
    get 'List all projekt notifications' do
      tags 'Notifications'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all notifications across all projekt phases.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt notifications found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:notif_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:notif_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }

        before do
          notif_phase1.projekt_notifications.create!(title: 'Notification 1', body: 'Body 1')
          notif_phase2.projekt_notifications.create!(title: 'Notification 2', body: 'Body 2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     notifications: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ProjektNotification' }
                     }
                   },
                   required: ['notifications']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/notifications/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Notification ID'

    get 'Retrieve a projekt notification' do
      tags 'Notifications'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single notification by ID.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt notification found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:created_notification) { notif_phase.projekt_notifications.create!(title: 'Update') }
        let(:id) { created_notification.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_notification: { '$ref' => '#/components/schemas/ProjektNotification' }
                   },
                   required: ['projekt_notification']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt notification not found' do
        let(:id) { 999999 }
        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt notification' do
      tags 'Notifications'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt notification. Allows modifying notification title, body, and link information. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_notification, in: :body, description: 'Attributes to update on the notification', schema: {
        type: :object,
        properties: {
          projekt_notification: {
            type: :object,
            properties: {
              title: { type: :string },
              body: { type: :string, nullable: true },
              link_text: { type: :string, nullable: true },
              link_url: { type: :string, nullable: true },
              segment_recipient: { type: :string, nullable: true }
            }
          }
        }
      }

      response '200', 'projekt notification updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:created_notification) { notif_phase.projekt_notifications.create!(title: 'Update') }
        let(:id) { created_notification.id }
        let(:projekt_notification) do
          { projekt_notification: { body: 'Updated body' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_notification: { '$ref' => '#/components/schemas/ProjektNotification' }
                   },
                   required: ['projekt_notification']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:created_notification) { notif_phase.projekt_notifications.create!(title: 'Update') }
        let(:id) { created_notification.id }
        let(:projekt_notification) do
          { projekt_notification: { link_url: 'not-a-url' } }
        end

        before do
          allow_any_instance_of(ProjektNotification).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Link url is invalid'])
          allow_any_instance_of(ProjektNotification).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:id) { existing_projekt_notification.id } }
    end

    delete 'Delete a projekt notification' do
      tags 'Notifications'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt notification. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt notification deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:created_notification) { notif_phase.projekt_notifications.create!(title: 'Update') }
        let(:id) { created_notification.id }

        schema type: :object,
               properties: { message: { type: :string } },
               required: ['message']

        run_test!
      end

      response '422', 'unable to delete projekt notification' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:notif_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::ProjektNotificationPhase', active: true) }
        let(:created_notification) { notif_phase.projekt_notifications.create!(title: 'Update') }
        let(:id) { created_notification.id }

        before do
          allow_any_instance_of(ProjektNotification).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete notification'] })
          allow_any_instance_of(ProjektNotification).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_notification.id } }
    end
  end
end


