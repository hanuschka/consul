# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekts API', type: :request do
  # Authentication setup - create an ApiClient with an auth_token
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekts' do
    get 'List all projekts' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :only_visible, in: :query, type: :boolean, required: false,
                description: 'If true, returns only activated projekts with published custom pages that are shown in overview'
      parameter name: :include_phases, in: :query, type: :boolean, required: false,
                description: 'If false, excludes projekt phases from response. Default is true.'
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: 'If false, excludes content blocks from response. Default is true.'

      response '200', 'projekts found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                    projekts: {
                      type: :array,
                      items: { '$ref' => '#/components/schemas/Projekt' }
                    }
                   },
                   required: ['projekts']
                 }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt, in: :body, schema: {
        type: :object,
        properties: {
          projekt: {
            type: :object,
            properties: {
              name: { type: :string },
              parent_id: { type: :integer, nullable: true },
              total_duration_start: { type: :string, format: :datetime, nullable: true },
              total_duration_end: { type: :string, format: :datetime, nullable: true },
              show_start_date_in_frontend: { type: :boolean },
              show_end_date_in_frontend: { type: :boolean },
              geozone_affiliated: { type: :boolean },
              order_number: { type: :integer },
              tag_list: { type: :string, nullable: true },
              related_sdg_list: { type: :string, nullable: true },
              landing_page_ids: { type: :array, items: { type: :integer } },
              geozone_affiliation_ids: { type: :array, items: { type: :integer } },
              sdg_goal_ids: { type: :array, items: { type: :integer } },
              individual_group_value_ids: { type: :array, items: { type: :integer } },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number },
                  longitude: { type: :number },
                  zoom: { type: :integer }
                }
              },
              image_attributes: {
                type: :object,
                properties: {
                  image: { type: :string, nullable: true },
                  cached_attachment: { type: :string, nullable: true },
                  title: { type: :string, nullable: true },
                  user_id: { type: :integer, nullable: true }
                }
              },
              projekt_manager_assignments_attributes: {
                type: :array,
                items: {
                  type: :object,
                  properties: {
                    id: { type: :integer, nullable: true },
                    projekt_manager_id: { type: :integer },
                    projekt_id: { type: :integer },
                    permissions: { type: :array, items: { type: :string } }
                  }
                }
              }
            },
            required: ['name']
          }
        },
        required: ['projekt']
      }

      response '201', 'projekt created' do
        let(:projekt) do
          {
            projekt: {
              name: 'Test Projekt',
              geozone_affiliated: false,
              show_start_date_in_frontend: true,
              show_end_date_in_frontend: true
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt: { '$ref' => '#/components/schemas/Projekt' }
                   },
                   required: ['projekt']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['projekt']['name']).to eq('Test Projekt')
        end
      end

      response '422', 'invalid request' do
        # Missing name triggers validation error
        let(:projekt) do
          {
            projekt: {
              name: ''
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        run_test!
      end
    end
  end

  path '/api/projekts/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    get 'Retrieve a projekt' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :include_phases, in: :query, type: :boolean, required: false,
                description: 'If false, excludes projekt phases from response. Default is true.'
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: 'If false, excludes content blocks from response. Default is true.'

      response '200', 'projekt found' do
        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt: { '$ref' => '#/components/schemas/Projekt' }
                   },
                   required: ['projekt']
                 }
               },
               required: ['data']

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }

        run_test!
      end

      response '404', 'projekt not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt, in: :body, schema: {
        type: :object,
        properties: {
          projekt: {
            type: :object,
            properties: {
              name: { type: :string },
              parent_id: { type: :integer, nullable: true },
              total_duration_start: { type: :string, format: :datetime, nullable: true },
              total_duration_end: { type: :string, format: :datetime, nullable: true },
              show_start_date_in_frontend: { type: :boolean },
              show_end_date_in_frontend: { type: :boolean },
              geozone_affiliated: { type: :boolean },
              order_number: { type: :integer },
              tag_list: { type: :string, nullable: true },
              related_sdg_list: { type: :string, nullable: true },
              landing_page_ids: { type: :array, items: { type: :integer } },
              geozone_affiliation_ids: { type: :array, items: { type: :integer } },
              sdg_goal_ids: { type: :array, items: { type: :integer } },
              individual_group_value_ids: { type: :array, items: { type: :integer } },
              map_location_attributes: {
                type: :object,
                properties: {
                  latitude: { type: :number },
                  longitude: { type: :number },
                  zoom: { type: :integer }
                }
              },
              image_attributes: {
                type: :object,
                properties: {
                  image: { type: :string, nullable: true },
                  cached_attachment: { type: :string, nullable: true },
                  title: { type: :string, nullable: true },
                  user_id: { type: :integer, nullable: true }
                }
              }
            }
          }
        },
        required: ['projekt']
      }

      response '200', 'projekt updated' do
        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              name: 'Updated Name'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     projekt: { '$ref' => '#/components/schemas/Projekt' }
                   },
                   required: ['projekt']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'projekt not found' do
        let(:id) { 999999 }
        let(:projekt) do
          {
            projekt: {
              name: 'Updated Name'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              name: ''  # Invalid - name can't be blank
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        run_test!
      end
    end

    delete 'Delete a projekt' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'projekt deleted' do
        let(:test_projekt) { Projekt.create!(name: 'To Delete') }
        let(:id) { test_projekt.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'projekt not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete projekt' do
        let(:test_projekt) { Projekt.create!(name: 'Cannot Delete') }
        let(:id) { test_projekt.id }

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: { type: :object }
                   }
                 }
               }

        # Mock destroy failure to trigger 422 response
        before do
          # Create a null object mock that accepts any method call
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete projekt'] })

          allow_any_instance_of(Projekt).to receive(:destroy).and_return(false)
          allow_any_instance_of(Projekt).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end

  path '/api/projekts/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update a projekt setting' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :setting, in: :body, schema: {
        type: :object,
        properties: {
          setting: {
            type: :object,
            properties: {
              key: { type: :string, description: 'Setting key' },
              value: { type: :string, description: 'Setting value' }
            },
            required: ['key', 'value']
          }
        },
        required: ['setting']
      }

      response '200', 'setting updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt with Setting') }
        let(:id) { test_projekt.id }
        let(:setting) do
          {
            setting: {
              key: 'test_setting',
              value: 'test_value'
            }
          }
        end

        # Create the setting before the test runs
        before do
          test_projekt.projekt_settings.create!(key: 'test_setting', value: 'old_value')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     setting: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         key: { type: :string },
                         value: { type: :string },
                         projekt_id: { type: :integer }
                       },
                       required: %w[id key value projekt_id]
                     }
                   },
                   required: ['setting']
                 },
                 message: { type: :string }
               },
               required: %w[data message]

        run_test!
      end

      response '404', 'setting not found' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:setting) do
          {
            setting: {
              key: 'nonexistent_setting',
              value: 'test_value'
            }
          }
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: {
                       type: :array,
                       items: { type: :string }
                     }
                   }
                 }
               }

        run_test!
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:setting) do
          {
            setting: {
              key: 'existing_setting',
              value: 'invalid_value'  # This will fail validation
            }
          }
        end

        # Create the setting first, then mock update to fail
        before do
          test_projekt.projekt_settings.create!(key: 'existing_setting', value: 'old_value')

          # Mock the update to fail validation
          allow_any_instance_of(ProjektSetting).to receive(:update).and_return(false)

          # Create errors mock for validation failure
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Value is invalid'])
          allow_any_instance_of(ProjektSetting).to receive(:errors).and_return(errors_mock)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     messages: {
                       type: :array,
                       items: { type: :string }
                     }
                   }
                 }
               }

        run_test!
      end
    end
  end
end


