# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'API 404 Not Found', type: :request, openapi_spec: 'v1/swagger.yaml' do
  path '/api/{invalid_path}' do
    parameter name: :invalid_path, in: :path, type: :string, description: 'Invalid API path'

    get 'Invalid API endpoint GET request' do
      tags 'Error Handling'
      produces 'application/json'

      response '404', 'endpoint not found' do
        let(:invalid_path) { 'nonexistent_endpoint' }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   },
                   required: ['type', 'messages']
                 }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('not_found')
          expect(data['error']['messages']).to be_a(Array)
          expect(data['error']['messages'].first).to include('endpoint does not exist')
        end
      end
    end

    post 'Invalid API endpoint POST request' do
      tags 'Error Handling'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          data: { type: :object }
        }
      }

      response '404', 'endpoint not found' do
        let(:invalid_path) { 'nonexistent_endpoint' }
        let(:body) { { data: {} } }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   },
                   required: ['type', 'messages']
                 }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('not_found')
          expect(response.status).to eq(404)
        end
      end
    end

    patch 'Invalid API endpoint PATCH request' do
      tags 'Error Handling'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          data: { type: :object }
        }
      }

      response '404', 'endpoint not found' do
        let(:invalid_path) { 'nonexistent_endpoint' }
        let(:body) { { data: {} } }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   },
                   required: ['type', 'messages']
                 }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('not_found')
          expect(response.status).to eq(404)
        end
      end
    end

    put 'Invalid API endpoint PUT request' do
      tags 'Error Handling'
      consumes 'application/json'
      produces 'application/json'

      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          data: { type: :object }
        }
      }

      response '404', 'endpoint not found' do
        let(:invalid_path) { 'nonexistent_endpoint' }
        let(:body) { { data: {} } }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   },
                   required: ['type', 'messages']
                 }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('not_found')
          expect(response.status).to eq(404)
        end
      end
    end

    delete 'Invalid API endpoint DELETE request' do
      tags 'Error Handling'
      produces 'application/json'

      response '404', 'endpoint not found' do
        let(:invalid_path) { 'nonexistent_endpoint' }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   },
                   required: ['type', 'messages']
                 }
               },
               required: ['error']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('not_found')
          expect(response.status).to eq(404)
        end
      end
    end
  end
end
