require 'swagger_helper'

RSpec.describe 'Deficiency Report Intake Channels API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/deficiency_report_intake_channels' do
    get 'List deficiency report intake channels' do
      tags 'Deficiency Report Intake Channels'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve the intake channels a deficiency report can reach the municipality through (counter, phone, letter, ...), in the order configured in /adm. Send a channel's id as `deficiency_report_intake_channel_id` when creating or updating a deficiency report. The channel marked `default` is used when a report is created without one.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'deficiency report intake channels found' do
        before do
          create(:deficiency_report_intake_channel, name: 'Phone', given_order: 2)
          create(:deficiency_report_intake_channel, name: 'Counter', given_order: 1, default: true)
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     deficiency_report_intake_channels: {
                       type: :array,
                       items: {
                         type: :object,
                         properties: {
                           id: { type: :integer, example: 3 },
                           name: { type: :string, example: 'Counter' },
                           default: { type: :boolean, description: 'Whether reports created without a channel get this one' },
                           given_order: { type: :integer, nullable: true, description: 'Position in the /adm ordering' }
                         },
                         required: %w[id name default]
                       }
                     }
                   },
                   required: ['deficiency_report_intake_channels']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          channels = JSON.parse(response.body)['data']['deficiency_report_intake_channels']

          expect(channels.map { |channel| channel['name'] }).to eq(%w[Counter Phone])
          expect(channels.first['default']).to be true
        end
      end

      unauthorized_response
    end
  end
end
