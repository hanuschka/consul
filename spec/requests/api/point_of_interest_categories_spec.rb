# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Point Of Interest Categories API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/point_of_interest_categories' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (PointOfInterestPhase)'

    post 'Create a projekt point of interest category' do
      tags 'Projekt Point Of Interest Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

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
    end
  end

  path '/api/point_of_interest_categories/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Point Of Interest Category ID'

    get 'Retrieve a projekt point of interest category' do
      tags 'Projekt Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]

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
    end

    patch 'Update a projekt point of interest category' do
      tags 'Projekt Point Of Interest Categories'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

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
    end

    delete 'Delete a projekt point of interest category' do
      tags 'Projekt Point Of Interest Categories'
      produces 'application/json'
      security [bearer_auth: []]

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
    end
  end
end
