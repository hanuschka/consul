# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Formular Fields API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }
  let(:formular_phase) { create_projekt_phase('ProjektPhase::FormularPhase') }
  let(:formular) { Formular.create!(projekt_phase: formular_phase) }

  before do
    Globalize.with_locale(:de) do
      formular.formular_fields.create!(
        name: 'Ihr Stadtteil',
        kind: 'dropdown',
        required: true,
        drop_down_options: 'Nord, Süd',
        email_for_confirmation_subject: 'Danke'
      )
    end
  end

  path '/api/formulars/{formular_id}/formular_fields' do
    parameter name: :formular_id, in: :path, type: :integer, description: 'Formular ID'

    get 'List the fields of a formular' do
      tags 'Formulars'
      produces 'application/json'
      security [bearer_auth: []]
      description "Fields of the form in display order, primary fields first and follow-up fields after them, with their labels in every language. Submissions are never returned. Admin clients also receive the confirmation email settings in options. Clients with public_data access only get fields of phases shown to visitors.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'formular fields found' do
        let(:formular_id) { formular.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     formular_fields: { type: :array, items: { '$ref' => '#/components/schemas/FormularField' } }
                   },
                   required: ['formular_fields']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          field_data = JSON.parse(response.body)['data']['formular_fields'].first

          expect(field_data['kind']).to eq('dropdown')
          expect(field_data['translations']['de']['name']).to eq('Ihr Stadtteil')
          expect(field_data['options']).to include('drop_down_options' => 'Nord, Süd', 'email_for_confirmation_subject' => 'Danke')
        end
      end

      response '200', 'formular fields found with public_data access' do
        let(:formular_id) { formular.id }

        before { api_client.update!(access_level: :public_data) }

        run_test! do |response|
          field_data = JSON.parse(response.body)['data']['formular_fields'].first

          expect(field_data['options']).to eq('drop_down_options' => 'Nord, Süd')
        end
      end

      response '403', 'phase hidden from public_data clients' do
        let(:formular_id) { formular.id }

        before do
          api_client.update!(access_level: :public_data)
          formular_phase.update!(frontend_visibility: false)
        end

        run_test!
      end

      response '404', 'formular not found' do
        let(:formular_id) { 999_999 }

        run_test!
      end

      unauthorized_response { let(:formular_id) { 1 } }
      forbidden_response { let(:formular_id) { formular.id } }
    end
  end
end
