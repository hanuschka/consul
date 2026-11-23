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
            properties: Schemas::Polls::POLL_WRITE_PROPERTIES
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

        let(:projekt) { Projekt.create!(name: 'Projekt', activated: true) }
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
            properties: Schemas::Polls::POLL_WRITE_PROPERTIES
          }
        }
      }

      response '200', 'poll texts written in two languages' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:existing_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { existing_poll.id }
        let(:poll) do
          {
            poll: {
              show_summary_instead_of_questions: true,
              translations: {
                de: { name: 'Umfrage Marktplatz', closing_note: 'Danke fürs Mitmachen!' },
                en: { name: 'Market square poll', closing_note: 'Thank you for taking part!' }
              }
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

        run_test! do |response|
          poll_data = JSON.parse(response.body)['data']['poll']

          expect(poll_data['show_summary_instead_of_questions']).to be(true)
          expect(poll_data['translations']['de']['name']).to eq('Umfrage Marktplatz')
          expect(poll_data['translations']['en']['closing_note']).to eq('Thank you for taking part!')
        end
      end

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

  path '/api/polls/{id}/go_live' do
    parameter name: :id, in: :path, type: :integer, description: 'Poll ID'

    post 'Take a poll out of test mode' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "Ends the test mode of a poll, like the go-live button in the admin area. **Irreversible:** every answer, voter and booth result collected while the poll was in test mode is deleted, so real results start from zero. A poll that is already live is refused with 422. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'poll is live and the test votes are gone' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:test_poll) { voting_phase.polls.create!(name: 'Poll name', live: false) }
        let(:id) { test_poll.id }

        before do
          question = test_poll.questions.create!(
            title: 'Which square?',
            author: api_client.content_author,
            votation_type: VotationType.new(vote_type: :unique)
          )
          answer_option = question.question_answers.create!(title: 'Market square', given_order: 1)
          Poll::Answer.new(
            question: question,
            question_answer: answer_option,
            answer: 'Market square',
            author: api_client.content_author
          ).save!(validate: false)
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

        run_test! do |response|
          expect(JSON.parse(response.body)['data']['poll']['live']).to be(true)
          expect(Poll::Answer.where(question_id: test_poll.questions.ids).count).to eq(0)
        end
      end

      response '422', 'poll is already live' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:id) { voting_phase.polls.create!(name: 'Poll name', live: true).id }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['details']['live']).to eq(['poll is already live'])
        end
      end

      forbidden_response do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:id) { voting_phase.polls.create!(name: 'Poll name', live: false).id }
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/polls/{id}/results' do
    parameter name: :id, in: :path, type: :integer, description: 'Poll ID'

    get 'Aggregated results of a poll' do
      tags 'Polls'
      produces 'application/json'
      security [bearer_auth: []]
      description "Returns the aggregated results of a poll: participants, votes and voters per answer option, the weight distribution of weighted and rating questions, and the anonymous points of map questions. Single votes, open answer texts and who answered are never returned. Admin clients always get the results; read-only clients only once the public site shows them (the phase's results tab is public) and never while the poll is in test mode. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'poll results' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:results_poll) { voting_phase.polls.create!(name: 'Poll name') }
        let(:id) { results_poll.id }

        before do
          question = results_poll.questions.create!(
            title: 'How do you rate the plan?',
            author: api_client.content_author,
            votation_type: VotationType.new(vote_type: :multiple_with_weight)
          )
          answer_option = question.question_answers.create!(title: 'Plan A', given_order: 1)
          question.question_answers.create!(title: 'Plan B', given_order: 2)

          [2, 3].each do |weight|
            Poll::Answer.new(
              question: question,
              question_answer: answer_option,
              answer: 'Plan A',
              answer_weight: weight,
              author: api_client.content_author
            ).save!(validate: false)
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     results: { '$ref' => '#/components/schemas/PollResults' }
                   },
                   required: ['results']
                 }
               },
               required: ['data']

        run_test! do |response|
          question_data = JSON.parse(response.body)['data']['results']['questions'].first
          plan_a, plan_b = question_data['answers']

          expect(question_data['total_votes']).to eq(5)
          expect(plan_a['total_votes']).to eq(5)
          expect(plan_a['percentage']).to eq(100.0)
          expect(plan_a['voters_count']).to eq(1)
          expect(plan_a['weights']).to eq([{ 'weight' => 2, 'count' => 1 }, { 'weight' => 3, 'count' => 1 }])
          expect(plan_b['total_votes']).to eq(0)
        end
      end

      response '403', 'results not public for read-only clients' do
        before { api_client.update!(access_level: :public_data) }

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) do
          projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true, frontend_visibility: true)
        end
        let(:id) { voting_phase.polls.create!(name: 'Poll name').id }

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('forbidden')
        end
      end

      response '404', 'poll not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end
