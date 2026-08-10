# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Idea Officers API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  def create_user_for_officer
    geozone = Geozone.create!(name: "Zone #{SecureRandom.hex(2)}")
    User.create!(
      username: "officer_#{SecureRandom.hex(4)}",
      email: "officer_#{SecureRandom.hex(4)}@example.com",
      password: 'Password1!',
      geozone: geozone,
      terms_data_storage: '1',
      terms_data_protection: '1',
      terms_general: '1'
    )
  end

  path '/api/idea_officers' do
    get 'List idea officers' do
      tags 'Idea Officers'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all idea officers.#{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 500, max: 2000)'

      response '200', 'idea officers found' do
        before do
          2.times do |_i|
            user = create_user_for_officer
            Idea::Officer.create!(user: user)
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_officers: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_officers']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '200', 'idea officers found with public_data access' do
        before do
          api_client.update!(access_level: :public_data)
          2.times do |_i|
            user = create_user_for_officer
            Idea::Officer.create!(user: user)
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_officers: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_officers']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '200', 'idea officers with pagination' do
        before do
          5.times do |_i|
            user = create_user_for_officer
            Idea::Officer.create!(user: user)
          end
        end

        let(:page) { 1 }
        let(:per_page) { 2 }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     idea_officers: { type: :array, items: { type: :object } }
                   },
                   required: ['idea_officers']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['idea_officers'].length).to eq(2)
          expect(data['pagination']['current_page']).to eq(1)
          expect(data['pagination']['total_count']).to eq(5)
        end
      end

      unauthorized_response
    end

  end
end
