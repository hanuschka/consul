# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Questions API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/projekt_questions' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (QuestionPhase or LivestreamPhase)'

    post 'Create a projekt question' do
      tags 'Projekt Questions'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_question, in: :body, description: 'Projekt question creation payload', schema: {
        type: :object,
        properties: {
          projekt_question: {
            type: :object,
            properties: {
              projekt_livestream_id: { type: :integer, nullable: true },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string, nullable: true }
                  }
                }
              },
              question_options_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    _destroy: { type: :boolean, nullable: true },
                    translations_attributes: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          id: { type: :integer, nullable: true },
                          locale: { type: :string },
                          value: { type: :string, nullable: true },
                          _destroy: { type: :boolean, nullable: true }
                        }
                      }
                    }
                  }
                }
              }
            }
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
              translations_attributes: [
                { locale: 'en', title: 'Test Question' }
              ],
              question_options_attributes: [
                { translations_attributes: [{ locale: 'en', value: 'Option 1' }] },
                { translations_attributes: [{ locale: 'en', value: 'Option 2' }] }
              ]
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
              translations_attributes: []
            }
          }
        end

        before do
          allow_any_instance_of(ProjektQuestion).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title is required'])
          allow_any_instance_of(ProjektQuestion).to receive(:errors).and_return(errors_mock)
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

  path '/api/projekt_questions/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Question ID'

    get 'Retrieve a projekt question' do
      tags 'Projekt Questions'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt question found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            translations_attributes: [
              { locale: 'en', title: 'Test Question' }
            ]
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
    end

    patch 'Update a projekt question' do
      tags 'Projekt Questions'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt_question, in: :body, description: 'Attributes to update on the projekt question', schema: {
        type: :object,
        properties: {
          projekt_question: {
            type: :object,
            properties: {
              projekt_livestream_id: { type: :integer, nullable: true },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string, nullable: true }
                  }
                }
              },
              question_options_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    _destroy: { type: :boolean, nullable: true },
                    translations_attributes: {
                      type: :array,
                      items: {
                        type: :object,
                        properties: {
                          id: { type: :integer, nullable: true },
                          locale: { type: :string },
                          value: { type: :string, nullable: true },
                          _destroy: { type: :boolean, nullable: true }
                        }
                      }
                    }
                  }
                }
              }
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
            translations_attributes: [
              { locale: 'en', title: 'Original Question' }
            ]
          )
        end
        let(:id) { test_projekt_question.id }
        let(:projekt_question) do
          {
            projekt_question: {
              translations_attributes: [
                { locale: 'en', title: 'Updated Question', description: 'Updated description' }
              ]
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
              translations_attributes: [
                { locale: 'en', title: 'Updated Question' }
              ]
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
            translations_attributes: [
              { locale: 'en', title: 'Original Question' }
            ]
          )
        end
        let(:id) { test_projekt_question.id }
        let(:projekt_question) do
          {
            projekt_question: {
              translations_attributes: [
                { id: test_projekt_question.translations.find_by(locale: 'en').id, locale: 'en', title: '' }
              ]
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
    end

    delete 'Delete a projekt question' do
      tags 'Projekt Questions'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt question deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:question_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::QuestionPhase', active: true) }
        let(:projekt_question) do
          question_phase.questions.create!(
            translations_attributes: [
              { locale: 'en', title: 'Question To Delete' }
            ]
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
            translations_attributes: [
              { locale: 'en', title: 'Question' }
            ]
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
    end
  end
end
