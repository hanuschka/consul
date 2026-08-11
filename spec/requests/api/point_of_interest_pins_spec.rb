# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Point Of Interest Pins API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

let(:existing_poi_phase) { create_projekt_phase('ProjektPhase::PointOfInterestPhase') }
let(:existing_poi_category) do
  existing_poi_phase.projekt_point_of_interest_categories.create!(
    name: 'Existing Category', color: '#FF0000', icon: 'map-pin'
  )
end
let(:existing_poi_pin) do
  existing_poi_phase.projekt_point_of_interest_pins.create!(
    author: api_client.user,
    projekt_point_of_interest_category: existing_poi_category,
    map_location_attributes: { latitude: 52.52, longitude: 13.405, zoom: 15 }
  )
end

  path '/api/projekt_phases/{projekt_phase_id}/point_of_interest_pins' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (PointOfInterestPhase)'

    get 'List projekt point of interest pins for a projekt phase' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all point of interest pins for a specific projekt phase. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt point of interest pins found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:projekt_phase_id) { poi_phase.id }

        before do
          2.times do |i|
            pin = poi_phase.projekt_point_of_interest_pins.new(
              author: api_client.user,
              projekt_point_of_interest_category: category,
              map_location_attributes: {
                latitude: 52.5200 + i,
                longitude: 13.4050 + i,
                zoom: 15
              }
            )
            pin.save!
          end
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     pins: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['pins']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new point of interest pin on the map. Pins mark specific locations with descriptions and categories. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_point_of_interest_pin, in: :body, description: 'Projekt point of interest pin creation payload', schema: {
        type: :object,
        properties: {
          projekt_point_of_interest_pin: {
            type: :object,
            properties: {
              author_id: { type: :integer, nullable: true },
              projekt_point_of_interest_category_id: { type: :integer, nullable: true },
              description: { type: :string, nullable: true },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number, format: :float, nullable: true },
                  longitude: { type: :number, format: :float, nullable: true },
                  zoom: { type: :integer, nullable: true }
                }
              }
            }
          }
        },
        required: ['projekt_point_of_interest_pin']
      }

      response '201', 'projekt point of interest pin created' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:projekt_phase_id) { poi_phase.id }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              projekt_point_of_interest_category_id: category.id,
              map_location_attributes: {
                latitude: 52.5200,
                longitude: 13.4050,
                zoom: 15
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     pin: { type: :object }
                   },
                   required: ['pin']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:projekt_phase_id) { poi_phase.id }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              map_location_attributes: {
                latitude: 'invalid',
                longitude: 'invalid'
              }
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Map location is invalid'])
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:errors).and_return(errors_mock)
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

  path '/api/point_of_interest_pins' do
    get 'List all projekt point of interest pins' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a paginated list of all point of interest pins across all projekt phases. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, description: 'Pagination page number (**default:** 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Number of items per page (**default:** 500, max: 2000)', required: false

      response '200', 'projekt point of interest pins found' do
        let(:projekt1) { Projekt.create!(name: 'Projekt 1') }
        let(:projekt2) { Projekt.create!(name: 'Projekt 2') }
        let(:poi_phase1) { projekt1.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:poi_phase2) { projekt2.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category1) { poi_phase1.projekt_point_of_interest_categories.create!(name: 'Category 1', color: '#FF0000', icon: 'icon-1') }
        let(:category2) { poi_phase2.projekt_point_of_interest_categories.create!(name: 'Category 2', color: '#00FF00', icon: 'icon-2') }

        before do
          pin = poi_phase1.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category1,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!

          pin = poi_phase2.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category2,
            map_location_attributes: {
              latitude: 51.5074,
              longitude: -0.1278,
              zoom: 15
            }
          )
          pin.save!
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     pins: {
                       type: :array,
                       items: { type: :object }
                     }
                   },
                   required: ['pins']
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data']

        run_test!
      end

      unauthorized_response
    end
  end

  path '/api/point_of_interest_pins/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Point Of Interest Pin ID'

    get 'Retrieve a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single point of interest pin by ID. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'projekt point of interest pin found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:pin) do
          pin = poi_phase.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!
          pin
        end
        let(:id) { pin.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     pin: { type: :object }
                   },
                   required: ['pin']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt point of interest pin not found' do
        let(:id) { 999999 }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing point of interest pin. Allows modifying pin location, description, and category. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt_point_of_interest_pin, in: :body, description: 'Attributes to update on the projekt point of interest pin', schema: {
        type: :object,
        properties: {
          projekt_point_of_interest_pin: {
            type: :object,
            properties: {
              author_id: { type: :integer, nullable: true },
              projekt_point_of_interest_category_id: { type: :integer, nullable: true },
              description: { type: :string, nullable: true },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number, format: :float, nullable: true },
                  longitude: { type: :number, format: :float, nullable: true },
                  zoom: { type: :integer, nullable: true }
                }
              }
            }
          }
        },
        required: ['projekt_point_of_interest_pin']
      }

      response '200', 'projekt point of interest pin updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:test_pin) do
          pin = poi_phase.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!
          pin
        end
        let(:id) { test_pin.id }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              map_location_attributes: {
                latitude: 51.5074,
                longitude: -0.1278,
                zoom: 16
              }
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     pin: { type: :object }
                   },
                   required: ['pin']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt point of interest pin not found' do
        let(:id) { 999999 }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:test_pin) do
          pin = poi_phase.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!
          pin
        end
        let(:id) { test_pin.id }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              map_location_attributes: {
                latitude: 'invalid',
                longitude: 'invalid'
              }
            }
          }
        end

        before do
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:save).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Map location is invalid'])
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:errors).and_return(errors_mock)
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
      forbidden_response { let(:id) { existing_poi_pin.id } }
    end

    delete 'Delete a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a point of interest pin. This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt point of interest pin deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:pin) do
          pin = poi_phase.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!
          pin
        end
        let(:id) { pin.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt point of interest pin not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt point of interest pin' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:poi_phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::PointOfInterestPhase', active: true) }
        let(:category) { poi_phase.projekt_point_of_interest_categories.create!(name: 'Test Category', color: '#FF0000', icon: 'icon-name') }
        let(:pin) do
          pin = poi_phase.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category,
            map_location_attributes: {
              latitude: 52.5200,
              longitude: 13.4050,
              zoom: 15
            }
          )
          pin.save!
          pin
        end
        let(:id) { pin.id }

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
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete pin'] })
          allow_any_instance_of(ProjektPointOfInterestPin).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response { let(:id) { existing_poi_pin.id } }
    end
  end
end
