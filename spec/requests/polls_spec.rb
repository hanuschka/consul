# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Polls API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/polls' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (VotingPhase)'

    post 'Create a poll' do
      tags 'Polls'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :poll, in: :body, description: 'Poll creation payload', schema: {
        type: :object,
        properties: {
          poll: {
            type: :object,
            properties: {
              starts_at: { type: :string, format: :date_time, nullable: true },
              ends_at: { type: :string, format: :date_time, nullable: true },
              geozone_restricted: { type: :boolean, nullable: true },
              summary: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              budget_id: { type: :integer, nullable: true },
              geozone_ids: { type: :array, items: { type: :integer } },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    name: { type: :string, nullable: true },
                    summary: { type: :string, nullable: true },
                    description: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        },
        required: ['poll']
      }

      response '201', 'poll created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:projekt_phase_id) { voting_phase.id }
        let(:poll) do
          {
            poll: {
              starts_at: '2025-01-01T00:00:00Z',
              ends_at: '2025-01-31T23:59:59Z',
              summary: 'Summary',
              description: 'Description',
              translations_attributes: [
                { locale: 'en', name: 'Community Vote', summary: 'Summary', description: 'Description' }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     poll: { '$ref' => '#/components/schemas/Poll' }
                   },
                   required: ['poll']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:projekt_phase_id) { voting_phase.id }
        let(:poll) do
          { poll: { starts_at: 'invalid' } }
        end

        before do
          allow_any_instance_of(Poll).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Starts at is invalid'])
          allow_any_instance_of(Poll).to receive(:errors).and_return(errors_mock)
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

  path '/api/polls/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Poll ID'

    get 'Retrieve a poll' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'poll found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:created_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { created_poll.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     poll: { '$ref' => '#/components/schemas/Poll' }
                   },
                   required: ['poll']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'poll not found' do
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update a poll' do
      tags 'Polls'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :poll, in: :body, description: 'Attributes to update on the poll', schema: {
        type: :object,
        properties: {
          poll: {
            type: :object,
            properties: {
              starts_at: { type: :string, format: :date_time, nullable: true },
              ends_at: { type: :string, format: :date_time, nullable: true },
              geozone_restricted: { type: :boolean, nullable: true },
              summary: { type: :string, nullable: true },
              description: { type: :string, nullable: true },
              budget_id: { type: :integer, nullable: true },
              geozone_ids: { type: :array, items: { type: :integer } },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    name: { type: :string, nullable: true },
                    summary: { type: :string, nullable: true },
                    description: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        }
      }

      response '200', 'poll updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }
        let(:poll) do
          { poll: { summary: 'Updated summary' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     poll: { '$ref' => '#/components/schemas/Poll' }
                   },
                   required: ['poll']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }
        let(:poll) do
          { poll: { starts_at: 'invalid' } }
        end

        before do
          allow_any_instance_of(Poll).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Starts at is invalid'])
          allow_any_instance_of(Poll).to receive(:errors).and_return(errors_mock)
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

    delete 'Delete a poll' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'poll deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '422', 'unable to delete poll' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }

        before do
          allow_any_instance_of(Poll).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete poll'] })
          allow_any_instance_of(Poll).to receive(:errors).and_return(errors_mock)
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


