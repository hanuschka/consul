# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Milestone Statuses API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/milestone_statuses' do
    get 'List all milestone statuses' do
      tags 'Milestone Statuses'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all milestone statuses. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'milestone statuses found' do
        before do
          Milestone::Status.create!(name: 'In Progress')
          Milestone::Status.create!(name: 'Completed')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone_statuses: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['milestone_statuses']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end

    post 'Create a milestone status' do
      tags 'Milestone Statuses'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new milestone status for tracking project progress. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :milestone_status, in: :body, description: 'Milestone status creation payload', schema: {
        type: :object,
        properties: {
          milestone_status: {
            type: :object,
            properties: {
              name: { type: :string }
            },
            required: ['name']
          }
        },
        required: ['milestone_status']
      }

      response '201', 'milestone status created' do
        let(:milestone_status) do
          {
            milestone_status: {
              name: 'Planning'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone_status: { type: :object }
                   },
                   required: ['milestone_status']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:milestone_status) do
          {
            milestone_status: {
              name: ''
            }
          }
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

      unauthorized_response
      forbidden_response
    end
  end

  path '/api/milestone_statuses/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Milestone Status ID'

    get 'Retrieve a milestone status' do
      tags 'Milestone Statuses'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single milestone status by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'milestone status found' do
        let(:milestone_status) { Milestone::Status.create!(name: 'In Progress') }
        let(:id) { milestone_status.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone_status: { type: :object }
                   },
                   required: ['milestone_status']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'milestone status not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a milestone status' do
      tags 'Milestone Statuses'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing milestone status. Allows modifying the status name. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :milestone_status, in: :body, description: 'Attributes to update on the milestone status', schema: {
        type: :object,
        properties: {
          milestone_status: {
            type: :object,
            properties: {
              name: { type: :string }
            }
          }
        },
        required: ['milestone_status']
      }

      response '200', 'milestone status updated' do
        let(:test_milestone_status) { Milestone::Status.create!(name: 'Original Status') }
        let(:id) { test_milestone_status.id }
        let(:milestone_status) do
          {
            milestone_status: {
              name: 'Updated Status'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     milestone_status: { type: :object }
                   },
                   required: ['milestone_status']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'milestone status not found' do
        let(:id) { 999999 }
        let(:milestone_status) do
          {
            milestone_status: {
              name: 'Updated Status'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_milestone_status) { Milestone::Status.create!(name: 'Original Status') }
        let(:id) { test_milestone_status.id }
        let(:milestone_status) do
          {
            milestone_status: {
              name: ''
            }
          }
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

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end

    delete 'Delete a milestone status' do
      tags 'Milestone Statuses'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a milestone status. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'milestone status deleted' do
        let(:milestone_status) { Milestone::Status.create!(name: 'Status To Delete') }
        let(:id) { milestone_status.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'milestone status not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete milestone status' do
        let(:milestone_status) { Milestone::Status.create!(name: 'Status') }
        let(:id) { milestone_status.id }

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
          allow_any_instance_of(Milestone::Status).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete milestone status'] })
          allow_any_instance_of(Milestone::Status).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { 1 } }
    end
  end

end
