# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Poll Question Answers API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/poll_questions/{poll_question_id}/answers' do
    parameter name: :poll_question_id, in: :path, type: :integer, description: 'Poll Question ID'

    get 'List answers for a poll question' do
      tags 'Poll Question Answers'
      produces 'application/json'
      security [bearer_auth: []]
      description "List all answers for a specific poll question, paginated with pagination metadata. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page (**default:** 100)', required: false

      response '200', 'answers found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_question_id) { poll_question.id }

        before do
          poll_question.question_answers.create!(title: 'Answer 1', given_order: 1)
          poll_question.question_answers.create!(title: 'Answer 2', given_order: 2)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     answers: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/PollQuestionAnswer' }
                     }
                   },
                   required: ['answers']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      response '404', 'question not found' do
        let(:poll_question_id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:poll_question_id) { 1 } }
    end

    post 'Create a poll question answer' do
      tags 'Poll Question Answers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new answer for a poll question. If given_order is not provided, it will be auto-assigned to the next position. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :answer, in: :body, description: 'Poll question answer creation payload', schema: Schemas::Polls::POLL_QUESTION_ANSWER_CREATE_PARAMS

      response '201', 'answer created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_question_id) { poll_question.id }
        let(:answer) do
          {
            answer: {
              translations_attributes: [
                { locale: 'en', title: 'Yes' },
                { locale: 'de', title: 'Ja' }
              ],
              given_order: 1
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     answer: { '$ref' => '#/components/schemas/PollQuestionAnswer' }
                   },
                   required: ['answer']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_question_id) { poll_question.id }
        let(:answer) do
          { answer: { translations_attributes: [{ locale: 'en', title: '' }] } }
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
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_question_id) { poll_question.id }
        let(:answer) do
          {
            answer: {
              translations_attributes: [{ locale: 'en', title: 'Test' }],
              given_order: 1
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

      unauthorized_response { let(:poll_question_id) { 1 } }
    end
  end

  path '/api/poll_questions/{poll_question_id}/answers/order' do
    parameter name: :poll_question_id, in: :path, type: :integer, description: 'Poll Question ID'

    patch 'Reorder answers for a poll question' do
      tags 'Poll Question Answers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Reorder the answers of a poll question by providing an ordered list of answer IDs. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :body, in: :body, description: 'Ordered list of answer IDs', schema: {
        type: :object,
        properties: {
          ordered_list: {
            type: :array,
            items: { type: :integer },
            description: 'Array of answer IDs in desired order'
          }
        },
        required: ['ordered_list']
      }

      response '200', 'answers reordered' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_question_id) { poll_question.id }
        let(:answer1) { poll_question.question_answers.create!(title: 'First', given_order: 1) }
        let(:answer2) { poll_question.question_answers.create!(title: 'Second', given_order: 2) }
        let(:body) do
          { ordered_list: [answer2.id, answer1.id] }
        end

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      forbidden_response { let(:poll_question_id) { 1 } }

      unauthorized_response { let(:poll_question_id) { 1 } }
    end
  end

  path '/api/poll_question_answers/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Poll Question Answer ID'

    get 'Retrieve a poll question answer' do
      tags 'Poll Question Answers'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a specific poll question answer by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'answer found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_answer) { poll_question.question_answers.create!(title: 'Test Answer', given_order: 1) }
        let(:id) { poll_answer.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     answer: { '$ref' => '#/components/schemas/PollQuestionAnswer' }
                   },
                   required: ['answer']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'answer not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a poll question answer' do
      tags 'Poll Question Answers'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing poll question answer. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :answer, in: :body, description: 'Attributes to update on the answer', schema: Schemas::Polls::POLL_QUESTION_ANSWER_UPDATE_PARAMS

      response '200', 'answer updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_answer) { poll_question.question_answers.create!(title: 'Original', given_order: 1) }
        let(:id) { poll_answer.id }
        let(:answer) do
          {
            answer: {
              given_order: 5
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     answer: { '$ref' => '#/components/schemas/PollQuestionAnswer' }
                   },
                   required: ['answer']
                 }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test', author: author) }
        let(:poll_answer) { poll_question.question_answers.create!(title: 'Test', given_order: 1) }
        let(:id) { poll_answer.id }
        let(:answer) do
          { answer: { given_order: 2 } }
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

    delete 'Delete a poll question answer' do
      tags 'Poll Question Answers'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a poll question answer. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'answer deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test Question', author: author) }
        let(:poll_answer) { poll_question.question_answers.create!(title: 'To Delete', given_order: 1) }
        let(:id) { poll_answer.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'answer not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:voting_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::VotingPhase', active: true) }
        let(:poll) { voting_phase.polls.create!(name: 'Test Poll') }
        let(:author) do
          User.administrators.first || User.create!(
            username: 'admin_user', email: 'admin_spec@example.com',
            password: '12345678', terms_of_service: '1',
            confirmed_at: Time.current
          )
        end
        let(:poll_question) { poll.questions.create!(title: 'Test', author: author) }
        let(:poll_answer) { poll_question.question_answers.create!(title: 'Test', given_order: 1) }
        let(:id) { poll_answer.id }

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
