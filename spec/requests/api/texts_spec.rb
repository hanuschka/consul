# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Texts API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/texts' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LegislationPhase)'

    post 'Create a text' do
      tags 'Texts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :text, in: :body, description: 'Text creation payload', schema: {
        type: :object,
        properties: {
          text: {
            type: :object,
            properties: {
              start_date: { type: :string, format: :date, nullable: true },
              end_date: { type: :string, format: :date, nullable: true },
              debate_start_date: { type: :string, format: :date, nullable: true },
              debate_end_date: { type: :string, format: :date, nullable: true },
              draft_publication_date: { type: :string, format: :date, nullable: true },
              allegations_start_date: { type: :string, format: :date, nullable: true },
              allegations_end_date: { type: :string, format: :date, nullable: true },
              result_publication_date: { type: :string, format: :date, nullable: true },
              debate_phase_enabled: { type: :boolean, nullable: true },
              allegations_phase_enabled: { type: :boolean, nullable: true },
              draft_publication_enabled: { type: :boolean, nullable: true },
              result_publication_enabled: { type: :boolean, nullable: true },
              published: { type: :boolean, nullable: true },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string, nullable: true },
                    summary: { type: :string, nullable: true },
                    description: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        },
        required: ['text']
      }

      response '201', 'text created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }
        let(:text) do
          {
            text: {
              start_date: '2025-01-01',
              end_date: '2025-12-31',
              debate_start_date: '2025-02-01',
              debate_end_date: '2025-02-28',
              published: true,
              title: 'Text',
              translations_attributes: [
                { locale: 'en', title: 'Text', summary: 'Summary', description: 'Description' }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     text: { type: :object }
                   },
                   required: ['text']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }
        let(:text) do
          {
            text: {
              start_date: 'invalid_date'
            }
          }
        end

        before do
          allow_any_instance_of(Legislation::Process).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Start date is invalid'])
          allow_any_instance_of(Legislation::Process).to receive(:errors).and_return(errors_mock)
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

  path '/api/texts/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Text ID'

    get 'Retrieve a text' do
      tags 'Texts'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'text found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:text_record) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true,
            title: 'Test Text'
          )
        end
        let(:id) { text_record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     text: { type: :object }
                   },
                   required: ['text']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'text not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a text' do
      tags 'Texts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :text, in: :body, description: 'Attributes to update on the text', schema: {
        type: :object,
        properties: {
          text: {
            type: :object,
            properties: {
              start_date: { type: :string, format: :date, nullable: true },
              end_date: { type: :string, format: :date, nullable: true },
              debate_start_date: { type: :string, format: :date, nullable: true },
              debate_end_date: { type: :string, format: :date, nullable: true },
              draft_publication_date: { type: :string, format: :date, nullable: true },
              allegations_start_date: { type: :string, format: :date, nullable: true },
              allegations_end_date: { type: :string, format: :date, nullable: true },
              result_publication_date: { type: :string, format: :date, nullable: true },
              debate_phase_enabled: { type: :boolean, nullable: true },
              allegations_phase_enabled: { type: :boolean, nullable: true },
              draft_publication_enabled: { type: :boolean, nullable: true },
              result_publication_enabled: { type: :boolean, nullable: true },
              published: { type: :boolean, nullable: true },
              translations_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    locale: { type: :string },
                    title: { type: :string, nullable: true },
                    summary: { type: :string, nullable: true },
                    description: { type: :string, nullable: true }
                  }
                }
              }
            }
          }
        },
        required: ['text']
      }

      response '200', 'text updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:test_text) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: false,
            title: 'Original Text'
          )
        end
        let(:id) { test_text.id }
        let(:text) do
          {
            text: {
              published: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     text: { type: :object }
                   },
                   required: ['text']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'text not found' do
        let(:id) { 999999 }
        let(:text) do
          {
            text: {
              published: true
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:test_text) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: false,
            title: 'Test Process'
          )
        end
        let(:id) { test_text.id }
        let(:text) do
          {
            text: {
              start_date: 'invalid_date'
            }
          }
        end

        before do
          allow_any_instance_of(Legislation::Process).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Start date is invalid'])
          allow_any_instance_of(Legislation::Process).to receive(:errors).and_return(errors_mock)
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

    delete 'Delete a text' do
      tags 'Texts'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'text deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:text_record) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true,
            title: 'Text To Delete'
          )
        end
        let(:id) { text_record.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'text not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete text' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:text_record) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true
          )
        end
        let(:id) { text_record.id }

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
          allow_any_instance_of(Legislation::Process).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete text'] })
          allow_any_instance_of(Legislation::Process).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end
