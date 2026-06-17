# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekts API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

  path '/api/projekts' do
    get 'List all projekts' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a list of all projekts ordered by creation date (oldest first). By default returns only public projekts (activated with published pages). Users with public_data access level can only access public projekts. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :filter, in: :query, type: :string, required: false,
                description: <<~DESC
                  Filter projekts by lifecycle stage or special status. Default: 'index_order_all'. Valid values:

                  **Timeline-based filters** (all require projekt to be activated):
                  - 'index_order_underway': Projekts in current/active phase where at least one phase is currently accepting contributions (current_at date is today). Indicators of active participation.
                  - 'index_order_ongoing': Projekts currently within their date range but with no active phases accepting contributions (all phases have finished or not yet started).
                  - 'index_order_upcoming': Projekts not yet started (start date is in the future). Shows planned projects to participants.
                  - 'index_order_expired': Projekts past their end date. Shows completed projects.

                  **Special status filters**:
                  - 'index_order_all': All activated projekts with published pages shown in overview (default). Broader view excluding special lists.
                  - 'index_order_individual_list': Projekts configured to appear in individual lists (separate display area). Requires 'show_in_individual_list' setting.
                  - 'index_order_drafts': Draft or inactive projekts (not activated). Admin only. Useful for content management and previewing unpublished projects.

                  Results are ordered by creation date (oldest first).
                DESC
      parameter name: :only_public, in: :query, type: :boolean, required: false,
                description: 'If false, returns all projekts (admin only). Default: true (returns activated projekts with published pages shown in overview). Users with public_data access can only access public projekts.'
      parameter name: :include_phases, in: :query, type: :boolean, required: false,
                description: 'If true, includes projekt phases in response with full phase details including type, active status, and dates. Users with public_data access will only see phases that are: visible to frontend (frontend_visibility=true), active, and within the current date range. Admin users see all phases. Default: false (excludes phases).'
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: 'If true, includes content blocks in response with HTML content organized by locale. Default: false (excludes content blocks).'

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

      response '200', 'projekts found with public_data access' do
        before do
          api_client.update!(access_level: :public_data)
        end

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

      response '200', 'projekts found filtered by status' do
        let(:filter) { 'index_order_all' }

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

      unauthorized_response
    end

    post 'Create a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Create a new projekt with the provided configuration. Supports hierarchy (sub-projekts), geographic restrictions, phases, and manager assignments. The response includes the full projekt object with all nested relationships. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt, in: :body, description: 'Projekt creation payload with required name and optional configuration (dates, geozones, phases, managers, etc.)', schema: { '$ref' => '#/components/schemas/ProjektCreateParams' }

      response '201', 'projekt created successfully' do
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:projekt) do
          {
            projekt: {
              name: 'Test Projekt',
              geozone_affiliated: false
            }
          }
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response
    end
  end

  path '/api/projekts/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    get 'Retrieve a projekt' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a single projekt by ID with all its details. Can optionally include/exclude nested phases and content blocks. Returns full projekt hierarchy information, page metadata, and settings. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :include_phases, in: :query, type: :boolean, required: false,
                description: 'If true, includes projekt phases in response with all phases, settings, and configuration. Users with public_data access will only see phases that are: visible to frontend (frontend_visibility=true), active, and within the current date range. Admin users see all phases. Default: false (excludes phases).'
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: 'If true, includes content blocks in response with all localized content blocks. Default: false (excludes content blocks).'

      response '200', 'projekt found and returned' do
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

      response '403', 'forbidden - insufficient access' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        before do
          api_client.update_column(:access_level, nil)
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'projekt found with public_data access (public projekt only)' do
        before do
          api_client.update!(access_level: :public_data)
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

        let(:test_projekt) do
          projekt = Projekt.create!(name: 'Public Test Projekt')
          projekt.projekt_settings.find_or_create_by(key: 'projekt_feature.main.activate').update!(value: 'active')
          projekt.projekt_settings.find_or_create_by(key: 'projekt_feature.general.show_in_overview_page').update!(value: 'active')
          projekt.page.update!(status: 'published')
          projekt
        end
        let(:id) { test_projekt.id }

        run_test!
      end

      response '403', 'forbidden - public_data cannot access non-public projekt' do
        before do
          api_client.update!(access_level: :public_data)
        end

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

        let(:test_projekt) { Projekt.create!(name: 'Private Test Projekt') }
        let(:id) { test_projekt.id }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    patch 'Update a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update an existing projekt with new values. All fields are optional - only provide the fields you want to change. Returns the updated projekt object. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt, in: :body, description: 'Projekt attributes to update (name, dates, visibility settings, geozones, phases, managers, etc.). Any field not provided remains unchanged.', schema: { '$ref' => '#/components/schemas/ProjektUpdateParams' }

      response '200', 'projekt updated successfully' do
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

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
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a projekt' do
      tags 'Projekts'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a projekt and all associated data (phases, comments, votes, etc.). This action is permanent and cannot be undone. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'projekt deleted successfully' do
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'To Delete') }
        let(:id) { test_projekt.id }

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/projekts/{id}/update_page' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt page attributes (title/subtitle)' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update the projekt page title and subtitle that appear on the frontend. Title and subtitle are displayed prominently on the projekt overview page. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :page, in: :body, description: 'Page attributes containing title (main heading) and subtitle (tagline) to update', schema: {
        type: :object,
        properties: {
          page: {
            type: :object,
            properties: {
              title: { type: :string, nullable: true },
              subtitle: { type: :string, nullable: true }
            }
          }
        }
      }

      response '200', 'projekt page updated' do
        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:page) do
          {
            page: {
              title: 'New Title',
              subtitle: 'New Subtitle'
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

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:page) do
          { page: { title: '' } }
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

        before do
          allow_any_instance_of(SiteCustomization::Page).to receive(:update).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Title is invalid'])
          allow_any_instance_of(SiteCustomization::Page).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:page) do
          {
            page: {
              title: 'New Title',
              subtitle: 'New Subtitle'
            }
          }
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/projekts/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update a projekt setting' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update a specific projekt configuration setting identified by key. Settings control feature flags and behaviors (e.g., show_map, enable_comments). Creates the setting if it does not exist, otherwise updates the existing value. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :setting, in: :body, description: 'Setting key/value pair: key identifies the setting (e.g., show_map, enable_comments), value is the new setting value', schema: {
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
          test_projekt.projekt_settings.create!(key: 'test_setting', value: 'old_value')
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:setting) do
          {
            setting: {
              key: 'test_setting',
              value: 'test_value'
            }
          }
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end

  path '/api/projekts/{id}/update_body' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt content block body' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Update the main content block body (HTML) for a projekt. This is the primary rich-text description that appears on the projekt detail page. Supports HTML formatting. Updates the default locale content block. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt, in: :body, description: 'Content block body containing HTML-formatted text for the projekt description', schema: {
        type: :object,
        properties: {
          projekt: {
            type: :object,
            properties: {
              body: { type: :string, description: 'HTML content for the content block body' }
            },
            required: ['body']
          }
        },
        required: ['projekt']
      }

      response '200', 'content block body updated' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              body: '<p>Updated content block body</p>'
            }
          }
        end

        before do
          test_projekt.content_blocks.create!(
            name: 'custom',
            locale: 'de',
            body: '<p>Original body</p>',
            key: "projekt_content_block_#{test_projekt.id}_1",
            position: 1
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     content_block: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         body: { type: :string },
                         name: { type: :string },
                         locale: { type: :string },
                         position: { type: :integer }
                       }
                     }
                   },
                   required: ['content_block']
                 },
                 message: { type: :string }
               },
               required: %w[data message]

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['data']['content_block']['body']).to eq('<p>Updated content block body</p>')
          expect(data['message']).to eq('Content block body updated successfully')
        end
      end

      response '404', 'content block not found' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt Without Content Block') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              body: '<p>New body</p>'
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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['messages']).to include('No content block found for this project')
        end
      end

      response '422', 'invalid request' do
        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              body: 'invalid body'
            }
          }
        end

        before do
          content_block = test_projekt.content_blocks.create!(
            name: 'custom',
            locale: 'de',
            body: '<p>Original body</p>',
            key: "projekt_content_block_#{test_projekt.id}_1",
            position: 1
          )

          allow_any_instance_of(SiteCustomization::ContentBlock).to receive(:update).and_return(false)

          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:full_messages).and_return(['Body is invalid'])
          allow_any_instance_of(SiteCustomization::ContentBlock).to receive(:errors).and_return(errors_mock)
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              body: '<p>New body content</p>'
            }
          }
        end

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

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:id) { 1 } }
    end
  end
end


