# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Questions API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_question_phase) { create_projekt_phase('ProjektPhase::QuestionPhase') }
let(:existing_projekt_question) do
  existing_question_phase.questions.create!(title: 'Existing Question')
end
let(:existing_livestream) do
  create_projekt_phase('ProjektPhase::LivestreamPhase').projekt_livestreams.create!(
    url: 'https://example.com/existing_livestream',
    title: 'Existing Livestream',
    video_platform: 'youtube'
  )
end

  path '/api/projekt_phases/{projekt_phase_id}/questions' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (QuestionPhase or LivestreamPhase)'

    get 'List projekt questions for a projekt phase' do
      tags 'Questions'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all questions from a specific projekt phase. Questions can be standalone survey questions or livestream questions. Each question includes its options and answer statistics. Returns paginated results. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt questions found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_phase_id) { question_phase.id }

        before do
          question_phase.questions.create!(
            title: 'Test Question 1'
          )
          question_phase.questions.create!(
            title: 'Test Question 2'
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     questions: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['questions']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt question' do
      tags 'Questions'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new projekt question in a specific phase. Questions can be created as: (1) root questions in a QuestionPhase, (2) livestream questions in a LivestreamPhase by specifying projekt_livestream_id. Questions support multiple choice options via nested question_options_attributes. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_question, in: :body, description: 'Projekt question creation payload', schema: {
        type: :object,
        properties: {
          projekt_question: {
            type: :object,
            properties: {
              title: { type: :string, description: 'Title of the question' },
              projekt_livestream_id: { type: :integer, nullable: true, description: 'Optional: ID of the livestream to associate this question with. If provided, validates that the livestream exists and the question becomes a livestream question.' }
            },
            required: ['title']
          }
        },
        required: ['projekt_question']
      }

      response '201', 'projekt question created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_phase_id) { question_phase.id }
        let(:projekt_question) do
          {
            projekt_question: {
              title: 'Test Question'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_question: { type: :object }
                   },
                   required: ['projekt_question']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_phase_id) { question_phase.id }
        let(:projekt_question) do
          {
            projekt_question: {
              title: ''
            }
          }
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
      forbidden_response { let(:projekt_phase_id) { existing_question_phase.id } }
    end
  end

  path '/api/questions' do
    get 'List all projekt questions' do
      tags 'Questions'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all projekt questions across all phases. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt questions found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:question_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:question_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }

        before do
          question_phase1.questions.create!(
            title: 'Test Question 1'
          )
          question_phase2.questions.create!(
            title: 'Test Question 2'
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     questions: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['questions']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/questions/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Question ID'

    get 'Retrieve a projekt question' do
      tags 'Questions'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single projekt question by ID with all its details and options. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt question found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:id) { projekt_question.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_question: { type: :object }
                   },
                   required: ['projekt_question']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt question not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt question' do
      tags 'Questions'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt question. Allows modifying question text and associated options. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_question, in: :body, description: 'Attributes to update on the projekt question', schema: {
        type: :object,
        properties: {
          projekt_question: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              projekt_livestream_id: { type: :integer, nullable: true }
            }
          }
        },
        required: ['projekt_question']
      }

      response '200', 'projekt question updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:test_projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:id) { test_projekt_question.id }
        let(:projekt_question) do
          {
            projekt_question: {
              title: 'Updated Question'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_question: { type: :object }
                   },
                   required: ['projekt_question']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt question not found' do
        let(:id) { 999999 }
        let(:projekt_question) do
          {
            projekt_question: {
              title: 'Updated Question'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:test_projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:id) { test_projekt_question.id }
        let(:projekt_question) do
          {
            projekt_question: {
              title: ''
            }
          }
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
      forbidden_response { let(:id) { existing_projekt_question.id } }
    end

    delete 'Delete a projekt question' do
      tags 'Questions'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt question and all associated options. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt question deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:id) { projekt_question.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt question not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt question' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:id) { projekt_question.id }

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
          allow_any_instance_of(ProjektQuestion).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt question'] })
          allow_any_instance_of(ProjektQuestion).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_projekt_question.id } }
    end
  end

  path '/api/livestreams/{livestream_id}/questions' do
    parameter name: :livestream_id, in: :path, type: :integer, description: 'Projekt Livestream ID'

    post 'Create a question for a livestream' do
      tags 'Questions'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a question attached to a specific livestream. The question is associated with the livestream and its projekt phase automatically. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_question, in: :body, description: 'Projekt question creation payload', schema: {
        type: :object,
        properties: {
          projekt_question: {
            type: :object,
            properties: {
              title: { type: :string, description: 'Title of the question' }
            },
            required: ['title']
          }
        },
        required: ['projekt_question']
      }

      response '201', 'projekt question created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:livestream) { livestream_phase.projekt_livestreams.create!(title: 'Livestream', url: 'https://example.com/live') }
        let(:livestream_id) { livestream.id }
        let(:projekt_question) do
          { projekt_question: { title: 'Livestream Question' } }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt_question: { type: :object }
                   },
                   required: ['projekt_question']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:livestream_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LivestreamPhase', active: true) }
        let(:livestream) { livestream_phase.projekt_livestreams.create!(title: 'Livestream', url: 'https://example.com/live') }
        let(:livestream_id) { livestream.id }
        let(:projekt_question) do
          { projekt_question: { title: '' } }
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

      unauthorized_response { let(:livestream_id) { 1 } }
      forbidden_response { let(:livestream_id) { existing_livestream.id } }
    end
  end
end
