# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Formulars API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  FORMULAR_RESPONSE_SCHEMA = {
    type: :object,
    properties: {
      id: {
        type: :integer,
        description: 'Unique identifier for the formular',
        example: 1
      },
      projekt_phase_id: {
        type: :integer,
        description: 'ID of the projekt phase this formular belongs to',
        example: 5
      },
      formular_fields_count: {
        type: :integer,
        description: 'Number of form fields defined in this formular',
        example: 12
      },
      formular_answers_count: {
        type: :integer,
        description: 'Number of participant responses submitted to this formular',
        example: 45
      },
      projekt_phase: {
        type: :object,
        description: 'The projekt phase this formular belongs to',
        properties: {
          id: { type: :integer, example: 5 },
          title: { type: :string, nullable: true, example: 'Feedback Phase' },
          type: { type: :string, example: 'ProjektPhase::FormularPhase' },
          projekt_id: { type: :integer, example: 2 }
        }
      },
      projekt: {
        type: :object,
        description: 'The projekt this formular belongs to',
        properties: {
          id: { type: :integer, example: 2 },
          title: { type: :string, example: 'Community Survey' }
        }
      },
      created_at: {
        type: :string,
        format: :date_time,
        description: 'Timestamp when the formular was created',
        example: '2024-01-10T10:00:00Z'
      },
      updated_at: {
        type: :string,
        format: :date_time,
        description: 'Timestamp when the formular was last modified',
        example: '2024-01-15T14:30:00Z'
      }
    },
    required: %w[id projekt_phase_id created_at updated_at]
  }.freeze

  path '/api/projekt_phases/{projekt_phase_id}/formulars' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (FormularPhase)'

    get 'List formulars for a projekt phase' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all forms configured for a projekt phase. Forms are used to collect structured input from participants with customizable fields and validation rules.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 100, max: 2000)', required: false

      response '200', 'formulars found and returned' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:formular_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::FormularPhase', active: true) }
        let(:projekt_phase_id) { formular_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formulars: {
                       type: :array,
                       items: FORMULAR_RESPONSE_SCHEMA
                     }
                   },
                   required: ['formulars']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a formular' do
      tags 'Formulars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create the formular (form) for a FormularPhase. Each phase holds a single formular; its fields are managed separately. No request body attributes are required. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '201', 'formular created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:formular_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::FormularPhase', active: true) }
        let(:projekt_phase_id) { formular_phase.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: FORMULAR_RESPONSE_SCHEMA
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:formular_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::FormularPhase', active: true) }
        let(:projekt_phase_id) { formular_phase.id }

        before do
          allow_any_instance_of(Formular).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Formular is invalid'])
          allow_any_instance_of(Formular).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/formulars/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Formular ID'

    get 'Retrieve a formular' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single formular with all its metadata including field count and submission count. Returns information about the form structure and participant responses.#{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'formular found and returned' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: FORMULAR_RESPONSE_SCHEMA
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'formular not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a formular' do
      tags 'Formulars'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a formular. The formular has no editable attributes besides its projekt phase association; this endpoint persists the record and returns it. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'formular updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular: FORMULAR_RESPONSE_SCHEMA
                   },
                   required: ['formular']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'formular not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end

    delete 'Delete a formular' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a formular and all associated form fields and submitted answers. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'formular destroyed' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '422', 'unable to delete formular' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:projekt_phase) { ProjektPhase::FormularPhase.create!(projekt: test_projekt) }
        let(:test_formular) { Formular.create!(projekt_phase_id: projekt_phase.id) }
        let(:id) { test_formular.id }

        before do
          allow_any_instance_of(Formular).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete formular'] })
          allow_any_instance_of(Formular).to receive(:errors).and_return(errors_mock)
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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end
end
