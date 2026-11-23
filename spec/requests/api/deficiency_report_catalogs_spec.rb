require 'swagger_helper'

RSpec.describe 'Deficiency Report Catalogs API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/deficiency_report_statuses' do
    get 'List deficiency report statuses' do
      tags 'Deficiency Report Statuses'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve the statuses a deficiency report can have, in their configured order, with title and description in every language. Send a status id as `deficiency_report_status_id` when writing a report. Admin clients also get the notice e-mailed to the reporter and the reminder delay.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'statuses found' do
        before do
          DeficiencyReport::Status.create!(title: 'Erledigt', color: 'green', icon: 'check', given_order: 2, archive_reports: true)
          DeficiencyReport::Status.create!(title: 'Offen', color: 'red', icon: 'hourglass-start', given_order: 1, notice_text: 'Danke')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report_statuses: { type: :array, items: { '$ref' => '#/components/schemas/DeficiencyReportStatus' } }
                   },
                   required: ['deficiency_report_statuses']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          statuses = JSON.parse(response.body)['data']['deficiency_report_statuses']

          expect(statuses.map { |status| status['title'] }).to eq(%w[Offen Erledigt])
          expect(statuses.first['notice_text']).to eq('Danke')
        end
      end

      response '200', 'statuses for a read-only client, without workflow texts' do
        before do
          api_client.update!(access_level: :public_data)
          DeficiencyReport::Status.create!(title: 'Offen', color: 'red', icon: 'hourglass-start', notice_text: 'Danke', reminder_delay: 3)
        end

        run_test! do |response|
          status_data = JSON.parse(response.body)['data']['deficiency_report_statuses'].first

          expect(status_data.keys).not_to include('notice_text', 'reminder_delay')
        end
      end

      unauthorized_response
    end
  end

  path '/api/deficiency_report_subcategories' do
    get 'List deficiency report subcategories' do
      tags 'Deficiency Report Subcategories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve the subcategories of the deficiency report categories, in their configured order. Send a subcategory id as `deficiency_report_subcategory_id` when writing a report; it has to belong to the report's category.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :category_id, in: :query, type: :integer, required: false, description: 'Only the subcategories of this category'
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'subcategories of one category' do
        let(:road) { DeficiencyReport::Category.create!(name: 'Straße', color: 'blue', icon: 'road') }
        let(:light) { DeficiencyReport::Category.create!(name: 'Licht', color: 'yellow', icon: 'lightbulb') }
        let(:category_id) { road.id }

        before do
          DeficiencyReport::Subcategory.create!(category: road, name: 'Schlagloch', given_order: 1)
          DeficiencyReport::Subcategory.create!(category: light, name: 'Laterne defekt', given_order: 1)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report_subcategories: { type: :array, items: { '$ref' => '#/components/schemas/DeficiencyReportSubcategory' } }
                   },
                   required: ['deficiency_report_subcategories']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          subcategories = JSON.parse(response.body)['data']['deficiency_report_subcategories']

          expect(subcategories.map { |subcategory| subcategory['name'] }).to eq(['Schlagloch'])
          expect(subcategories.first.keys).not_to include('ai_hint')
        end
      end

      unauthorized_response
    end
  end

  path '/api/deficiency_report_answer_templates' do
    get 'List official answer templates' do
      tags 'Deficiency Report Answer Templates'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve the templates staff start official answers from.#{ApiAccessRequirements::ADMIN_REQUIRED}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'answer templates found' do
        before do
          DeficiencyReport::OfficialAnswerTemplate.create!(title: 'Weitergeleitet', text: 'Wir haben Ihre Meldung weitergeleitet.')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report_answer_templates: { type: :array, items: { '$ref' => '#/components/schemas/DeficiencyReportAnswerTemplate' } }
                   },
                   required: ['deficiency_report_answer_templates']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      response '403', 'read-only clients get no answer templates' do
        before { api_client.update!(access_level: :public_data) }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end

      unauthorized_response
    end
  end
end
