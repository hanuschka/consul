# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Notifications API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/projekt_notifications' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (ProjektNotificationPhase)'

    post 'Create a projekt notification' do
      tags 'Projekt Notifications'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_notification, in: :body, description: 'Projekt Notification creation payload', schema: {
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
    end
  end

  path '/api/projekt_notifications/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Notification ID'

    get 'Retrieve a projekt notification' do
      tags 'Projekt Notifications'
      produces 'application/json'
      security [bearer_auth: []]

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
    end

    patch 'Update a projekt notification' do
      tags 'Projekt Notifications'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

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
    end

    delete 'Delete a projekt notification' do
      tags 'Projekt Notifications'
      produces 'application/json'
      security [bearer_auth: []]

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
    end
  end
end


