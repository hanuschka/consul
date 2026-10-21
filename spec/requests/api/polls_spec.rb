# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Polls API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/polls' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (VotingPhase)'

    get 'List polls for a projekt phase' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "List all polls within a specific voting phase. Polls are voting mechanisms within a phase that allow communities to vote on various options. Returns paginated results with pagination metadata. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'polls found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:projekt_phase_id) { voting_phase.id }

        before do
          voting_phase.polls.create!(name: 'Poll 1', starts_at: '2025-01-01T00:00:00Z', ends_at: '2025-01-31T23:59:59Z')
          voting_phase.polls.create!(name: 'Poll 2', starts_at: '2025-02-01T00:00:00Z', ends_at: '2025-02-28T23:59:59Z')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     polls: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/Poll' }
                     }
                   },
                   required: ['polls']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a poll' do
      tags 'Polls'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new poll within a voting phase. Polls enable structured voting on community decisions. Each poll must have a name and can optionally include summary, description, and scheduling information (starts_at and ends_at). #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :poll, in: :body, description: 'Poll creation payload', schema: {
        type: :object,
        properties: {
          poll: {
            type: :object,
            properties: {
              name: { type: :string, description: 'Display name of the poll' },
              summary: { type: :string, nullable: true, description: 'Short summary of the poll topic' },
              description: { type: :string, nullable: true, description: 'Detailed description of what is being voted on' },
              starts_at: { type: :string, format: :date_time, nullable: true, description: 'When voting begins (ISO 8601 format)' },
              ends_at: { type: :string, format: :date_time, nullable: true, description: 'When voting ends (ISO 8601 format)' },
              geozone_restricted: { type: :boolean, nullable: true, description: 'Whether voting is restricted to specific geozones' },
              budget_id: { type: :integer, nullable: true, description: 'Optional: Associated budget ID if this is a budget voting poll' },
              geozone_ids: { type: :array, items: { type: :integer }, description: 'IDs of geozones where voting is allowed (if geozone_restricted is true)' }
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
              name: 'Community Vote',
              starts_at: '2025-01-01T00:00:00Z',
              ends_at: '2025-01-31T23:59:59Z',
              summary: 'Summary',
              description: 'Description'
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:projekt_phase_id) { voting_phase.id }
        let(:poll) do
          {
            poll: {
              name: 'Community Vote',
              starts_at: '2025-01-01T00:00:00Z',
              ends_at: '2025-01-31T23:59:59Z',
              summary: 'Summary',
              description: 'Description'
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

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/polls' do
    get 'List all polls' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "List all polls across all voting phases. Returns paginated results with polling information and current voting status. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'polls found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:voting_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:voting_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }

        before do
          voting_phase1.polls.create!(name: 'Poll 1', starts_at: '2025-01-01T00:00:00Z', ends_at: '2025-01-31T23:59:59Z')
          voting_phase2.polls.create!(name: 'Poll 2', starts_at: '2025-02-01T00:00:00Z', ends_at: '2025-02-28T23:59:59Z')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     polls: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/Poll' }
                     }
                   },
                   required: ['polls']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/polls/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Poll ID'

    get 'Retrieve a poll' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a specific poll by ID. Returns complete poll information including metadata, scheduling, and voting options. #{ApiAccessRequirements::GET_READ_ONLY}"

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

      response '200', 'poll found with public_data access' do
        before do
          api_client.update!(access_level: :public_data)
        end

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

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a poll' do
      tags 'Polls'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing poll. Allows modifying poll details such as name, timing, description, and geozone restrictions. Only the fields that need updating should be provided in the request. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :poll, in: :body, description: 'Attributes to update on the poll', schema: {
        type: :object,
        properties: {
          poll: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true, description: 'Display name of the poll' },
              summary: { type: :string, nullable: true, description: 'Short summary of the poll topic' },
              description: { type: :string, nullable: true, description: 'Detailed description of what is being voted on' },
              starts_at: { type: :string, format: :date_time, nullable: true, description: 'When voting begins (ISO 8601 format)' },
              ends_at: { type: :string, format: :date_time, nullable: true, description: 'When voting ends (ISO 8601 format)' },
              geozone_restricted: { type: :boolean, nullable: true, description: 'Whether voting is restricted to specific geozones' },
              budget_id: { type: :integer, nullable: true, description: 'Associated budget ID if this is a budget voting poll' },
              geozone_ids: { type: :array, items: { type: :integer }, description: 'IDs of geozones where voting is allowed' }
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }
        let(:poll) do
          { poll: { summary: 'Updated summary' } }
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

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a poll' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete an existing poll. Permanently removes the poll and all associated voting data. This operation cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }

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

      unauthorized_response { let(:id) { 1 } }
    end
  end
end


