# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Legislation Processes API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/legislation_processes' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (LegislationPhase)'

    post 'Create a legislation process' do
      tags 'Legislation Processes'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :legislation_process, in: :body, description: 'Legislation process creation payload', schema: {
        type: :object,
        properties: {
          legislation_process: {
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
        required: ['legislation_process']
      }

      response '201', 'legislation process created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }
        let(:legislation_process) do
          {
            legislation_process: {
              start_date: '2025-01-01',
              end_date: '2025-12-31',
              debate_start_date: '2025-02-01',
              debate_end_date: '2025-02-28',
              published: true,
              title: 'Legislation Process',
              translations_attributes: [
                { locale: 'en', title: 'Legislation Process', summary: 'Summary', description: 'Description' }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     legislation_process: { type: :object }
                   },
                   required: ['legislation_process']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:projekt_phase_id) { legislation_phase.id }
        let(:legislation_process) do
          {
            legislation_process: {
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

  path '/api/legislation_processes/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Legislation Process ID'

    get 'Retrieve a legislation process' do
      tags 'Legislation Processes'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'legislation process found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:legislation_process) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true,
            title: 'Test Legislation Process'
          )
        end
        let(:id) { legislation_process.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     legislation_process: { type: :object }
                   },
                   required: ['legislation_process']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'legislation process not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a legislation process' do
      tags 'Legislation Processes'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :legislation_process, in: :body, description: 'Attributes to update on the legislation process', schema: {
        type: :object,
        properties: {
          legislation_process: {
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
        required: ['legislation_process']
      }

      response '200', 'legislation process updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:test_legislation_process) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: false,
            title: 'Original Legislation Process'
          )
        end
        let(:id) { test_legislation_process.id }
        let(:legislation_process) do
          {
            legislation_process: {
              published: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     legislation_process: { type: :object }
                   },
                   required: ['legislation_process']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'legislation process not found' do
        let(:id) { 999999 }
        let(:legislation_process) do
          {
            legislation_process: {
              published: true
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:test_legislation_process) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: false,
            title: 'Test Process'
          )
        end
        let(:id) { test_legislation_process.id }
        let(:legislation_process) do
          {
            legislation_process: {
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

    delete 'Delete a legislation process' do
      tags 'Legislation Processes'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'legislation process deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:legislation_process) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true,
            title: 'Legislation Process To Delete'
          )
        end
        let(:id) { legislation_process.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'legislation process not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete legislation process' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:legislation_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::LegislationPhase', active: true) }
        let(:legislation_process) do
          Legislation::Process.create!(
            projekt_phase: legislation_phase,
            start_date: Date.today,
            end_date: Date.today + 1.year,
            published: true
          )
        end
        let(:id) { legislation_process.id }

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
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete legislation process'] })
          allow_any_instance_of(Legislation::Process).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end
