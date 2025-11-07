require 'swagger_helper'

RSpec.describe 'Deficiency Report Categories API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/deficiency_report_categories' do
    get 'List deficiency report categories' do
      tags 'Deficiency Report Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all deficiency report categories.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'

      response '200', 'deficiency report categories found' do
        before do
          2.times do |i|
            DeficiencyReport::Category.create!(
              name: "Category #{i+1}",
              color: 'blue',
              icon: 'road',
              given_order: i
            )
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report_categories: { type: :array, items: { type: :object } }
                   },
                   required: ['deficiency_report_categories']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end
    end
  end
end
