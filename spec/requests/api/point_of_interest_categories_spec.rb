# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Point Of Interest Categories API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_poi_phase) { create_projekt_phase('ProjektPhase::PointOfInterestPhase') }
let(:existing_poi_category) do
  existing_poi_phase.projekt_point_of_interest_categories.create!(
    name: 'Existing Category', color: '#FF0000', icon: 'map-pin'
  )
end

  path '/api/projekt_phases/{projekt_phase_id}/point_of_interest_categories' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (PointOfInterestPhase)'

    get 'List projekt point of interest categories for a projekt phase' do
      tags 'Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all point of interest categories for a specific projekt phase. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page (**default:** 100)', required: false

      response '200', 'projekt point of interest categories found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:projekt_phase_id) { poi_phase.id }

        before do
          poi_phase.projekt_point_of_interest_categories.create!(name: 'Category 1', color: '#FF0000', icon: 'icon-1')
          poi_phase.projekt_point_of_interest_categories.create!(name: 'Category 2', color: '#00FF00', icon: 'icon-2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     categories: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['categories']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt point of interest category' do
      tags 'Point Of Interest Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new point of interest category for organizing map pins and locations. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_point_of_interest_category, in: :body, description: 'Projekt point of interest category creation payload', schema: {
        type: :object,
        properties: {
          projekt_point_of_interest_category: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              color: { type: :string, nullable: true },
              icon: { type: :string, nullable: true }
            }
          }
        },
        required: ['projekt_point_of_interest_category']
      }

      response '201', 'projekt point of interest category created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:projekt_phase_id) { poi_phase.id }
        let(:projekt_point_of_interest_category) do
          {
            projekt_point_of_interest_category: {
              name: 'Test Category',
              color: '#FF0000',
              icon: 'map-pin'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     category: { type: :object }
                   },
                   required: ['category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:projekt_phase_id) { poi_phase.id }
        let(:projekt_point_of_interest_category) do
          {
            projekt_point_of_interest_category: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:projekt_phase_id) { existing_poi_phase.id } }
    end
  end

  path '/api/point_of_interest_categories' do
    get 'List all projekt point of interest categories' do
      tags 'Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all point of interest categories across all projekt phases. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page (**default:** 100)', required: false

      response '200', 'projekt point of interest categories found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:poi_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:poi_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }

        before do
          poi_phase1.projekt_point_of_interest_categories.create!(name: 'Category 1', color: '#FF0000', icon: 'icon-1')
          poi_phase2.projekt_point_of_interest_categories.create!(name: 'Category 2', color: '#00FF00', icon: 'icon-2')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     categories: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['categories']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/point_of_interest_categories/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Point Of Interest Category ID'

    get 'Retrieve a projekt point of interest category' do
      tags 'Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single point of interest category by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt point of interest category found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Test Category',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:id) { category.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     category: { type: :object }
                   },
                   required: ['category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt point of interest category not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt point of interest category' do
      tags 'Point Of Interest Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing point of interest category. Allows modifying category name and properties. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_point_of_interest_category, in: :body, description: 'Attributes to update on the projekt point of interest category', schema: {
        type: :object,
        properties: {
          projekt_point_of_interest_category: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              color: { type: :string, nullable: true },
              icon: { type: :string, nullable: true }
            }
          }
        },
        required: ['projekt_point_of_interest_category']
      }

      response '200', 'projekt point of interest category updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:test_category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Original Category',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:id) { test_category.id }
        let(:projekt_point_of_interest_category) do
          {
            projekt_point_of_interest_category: {
              name: 'Updated Category',
              color: '#00FF00'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     category: { type: :object }
                   },
                   required: ['category']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt point of interest category not found' do
        let(:id) { 999999 }
        let(:projekt_point_of_interest_category) do
          {
            projekt_point_of_interest_category: {
              name: 'Updated Category'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:test_category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Original Category',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:id) { test_category.id }
        let(:projekt_point_of_interest_category) do
          {
            projekt_point_of_interest_category: {
              name: ''
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Name is invalid'])
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:id) { existing_poi_category.id } }
    end

    delete 'Delete a projekt point of interest category' do
      tags 'Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a point of interest category. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt point of interest category deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Category To Delete',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:id) { category.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt point of interest category not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt point of interest category' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) do
          poi_phase.projekt_point_of_interest_categories.create!(
            name: 'Category',
            color: '#FF0000',
            icon: 'map-pin'
          )
        end
        let(:id) { category.id }

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
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete category'] })
          allow_any_instance_of(ProjektPointOfInterestCategory).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_poi_category.id } }
    end
  end
end
