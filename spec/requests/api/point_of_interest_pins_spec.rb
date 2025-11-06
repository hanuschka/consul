# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekt Point Of Interest Pins API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin).tap(&:reload) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekt_phases/{projekt_phase_id}/point_of_interest_pins' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (PointOfInterestPhase)'

    get 'List projekt point of interest pins for a projekt phase' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, description: 'Page number (default: 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page (default: 100)', required: false

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
              },
              translations_attributes: [
                {
                  locale: 'en',
                  description: "Pin #{i + 1}"
                }
              ]
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
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   }
                 }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

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
              translations_attributes: [
                {
                  locale: 'en',
                  description: 'Test pin description'
                }
              ],
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
    end
  end

  path '/api/point_of_interest_pins' do
    get 'List all projekt point of interest pins' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, description: 'Page number (default: 1)', required: false
      parameter name: :per_page, in: :query, type: :integer, description: 'Items per page (default: 100)', required: false

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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Pin from phase 1'
              }
            ]
          )
          pin.save!

          pin = poi_phase2.projekt_point_of_interest_pins.new(
            author: api_client.user,
            projekt_point_of_interest_category: category2,
            map_location_attributes: {
              latitude: 51.5074,
              longitude: -0.1278,
              zoom: 15
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Pin from phase 2'
              }
            ]
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
                 pagination: {
                   type: :object,
                   properties: {
                     current_page: { type: :integer },
                     total_pages: { type: :integer },
                     total_count: { type: :integer },
                     per_page: { type: :integer }
                   }
                 }
               },
               required: ['data']

        run_test!
      end
    end
  end

  path '/api/point_of_interest_pins/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt Point Of Interest Pin ID'

    get 'Retrieve a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]

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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Test pin'
              }
            ]
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
    end

    patch 'Update a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Original description'
              }
            ]
          )
          pin.save!
          pin
        end
        let(:id) { test_pin.id }
        let(:projekt_point_of_interest_pin) do
          {
            projekt_point_of_interest_pin: {
              translations_attributes: [
                {
                  locale: 'en',
                  description: 'Updated description'
                }
              ],
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
              translations_attributes: [
                {
                  locale: 'en',
                  description: 'Updated description'
                }
              ]
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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Original description'
              }
            ]
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
    end

    delete 'Delete a projekt point of interest pin' do
      tags 'Point Of Interest Pins'
      produces 'application/json'
      security [bearer_auth: []]

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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Pin To Delete'
              }
            ]
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
            },
            translations_attributes: [
              {
                locale: 'en',
                description: 'Pin'
              }
            ]
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
    end
  end
end
