# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Auth API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/auth/rotate_token' do
    post 'Rotate API access token' do
      tags 'Auth'
      produces 'application/json'
      security [bearer_auth: []]
      description 'Regenerates the access token for the authenticated API client. The old token is immediately invalidated and the new token is returned. Any authenticated client can rotate its own token.'

      response '200', 'token rotated successfully' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     access_token: { type: :string, example: 'sk_abc123...' }
                   },
                   required: ['access_token']
                 }
               },
               required: ['data']

        run_test!
      end

      response '200', 'old token is invalidated after rotation' do
        it 'returns 401 on subsequent request with old token' do
          old_token = api_client.access_token
          post '/api/auth/rotate_token', headers: { 'Authorization' => "Bearer #{old_token}" }
          expect(response).to have_http_status(:ok)

          post '/api/auth/rotate_token', headers: { 'Authorization' => "Bearer #{old_token}" }
          expect(response).to have_http_status(:unauthorized)
        end
      end

      response '401', 'unauthorized - missing or invalid token' do
        let(:Authorization) { 'Bearer invalid_token' }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test!
      end
    end
  end
end
