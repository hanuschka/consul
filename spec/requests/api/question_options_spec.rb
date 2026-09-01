# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Question Options API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_question_phase) { create_projekt_phase('ProjektPhase::QuestionPhase') }
let(:existing_projekt_question) do
  existing_question_phase.questions.create!(title: 'Existing Question')
end
let(:existing_question_option) do
  existing_projekt_question.question_options.create!(value: 'Existing Option')
end

  path '/api/questions/{question_id}/question_options' do
    parameter name: :question_id, in: :path, type: :integer, description: 'Projekt Question ID'

    post 'Create a question option' do
      tags 'Question Options'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new answer option for a question. Options are multiple choice answers that participants can select. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :question_option, in: :body, description: 'Question option creation payload', schema: {
        type: :object,
        properties: {
          question_option: {
            type: :object,
            properties: {
              value: { type: :string }
            }
          }
        },
        required: ['question_option']
      }

      response '201', 'question option created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:question_id) { projekt_question.id }
        let(:question_option) do
          {
            question_option: {
              value: 'Option 1'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question_option: { type: :object }
                   },
                   required: ['question_option']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'question not found' do
        let(:question_id) { 999999 }
        let(:question_option) do
          {
            question_option: {
              value: 'Option 1'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:question_id) { projekt_question.id }
        let(:question_option) do
          {
            question_option: {
              value: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektQuestionOption).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Value is required'])
          allow_any_instance_of(ProjektQuestionOption).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:question_id) { 1 } }

      forbidden_response { let(:question_id) { existing_projekt_question.id } }
    end
  end

  path '/api/question_options/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Question Option ID'

    get 'Retrieve a question option' do
      tags 'Question Options'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single question option by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'question option found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:question_option) do
          projekt_question.question_options.create!(
            value: 'Option 1'
          )
        end
        let(:id) { question_option.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question_option: { type: :object }
                   },
                   required: ['question_option']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'question option not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a question option' do
      tags 'Question Options'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing question option. Allows modifying option text and properties. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :question_option, in: :body, description: 'Attributes to update on the question option', schema: {
        type: :object,
        properties: {
          question_option: {
            type: :object,
            properties: {
              value: { type: :string }
            }
          }
        },
        required: ['question_option']
      }

      response '200', 'question option updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:test_option) do
          projekt_question.question_options.create!(
            value: 'Option 1'
          )
        end
        let(:id) { test_option.id }
        let(:question_option) do
          {
            question_option: {
              value: 'Updated Option'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     question_option: { type: :object }
                   },
                   required: ['question_option']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'question option not found' do
        let(:id) { 999999 }
        let(:question_option) do
          {
            question_option: {
              value: 'Updated Option'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:test_option) do
          projekt_question.question_options.create!(
            value: 'Option 1'
          )
        end
        let(:id) { test_option.id }
        let(:question_option) do
          {
            question_option: {
              value: ''
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

      forbidden_response { let(:id) { existing_question_option.id } }
    end

    delete 'Delete a question option' do
      tags 'Question Options'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a question option. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'question option deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:question_option) do
          projekt_question.question_options.create!(
            value: 'Option 1'
          )
        end
        let(:id) { question_option.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'question option not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete question option' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            title: 'Test Question'
          )
        end
        let(:question_option) do
          projekt_question.question_options.create!(
            value: 'Option 1'
          )
        end
        let(:id) { question_option.id }

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
          allow_any_instance_of(ProjektQuestionOption).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete question option'] })
          allow_any_instance_of(ProjektQuestionOption).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }

      forbidden_response { let(:id) { existing_question_option.id } }
    end
  end
end
