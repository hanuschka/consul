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
      description "Retrieve a list of all projekts. By default ordered by creation date (oldest first); use 'sort_by' and 'sort_direction' to change the ordering (e.g. sort_by=total_duration_end&sort_direction=asc surfaces projekts expiring next at the top). By default returns only public projekts (activated with published pages). Users with public_data access level can only access public projekts. Pagination is optional: by default all matching projekts are returned, but supplying 'page' (and optionally 'per_page', default 20) paginates the results and adds a 'pagination' object to the response. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :filter, in: :query, type: :string, required: false,
                description: <<~DESC
                  Filter projekts by lifecycle stage or special status. Valid values:

                  **Timeline-based filters** (all require projekt to be activated):
                  - 'index_order_underway': Projekts in current/active phase where at least one phase is currently accepting contributions (current_at date is today). Indicators of active participation.
                  - 'index_order_ongoing': Projekts currently within their date range but with no active phases accepting contributions (all phases have finished or not yet started).
                  - 'index_order_upcoming': Projekts not yet started (start date is in the future). Shows planned projects to participants.
                  - 'index_order_expired': Projekts past their end date. Shows completed projects.

                  **Special status filters**:
                  - 'index_order_all': All activated projekts with published pages shown in overview. Broader view excluding special lists.
                  - 'index_order_individual_list': Projekts configured to appear in individual lists (separate display area). Requires 'show_in_individual_list' setting.
                  - 'index_order_drafts': Draft or inactive projekts (not activated). Admin only. Useful for content management and previewing unpublished projects.

                  Results are ordered by creation date (oldest first).

                  **Default:** 'index_order_all'.
                DESC
      parameter name: :sort_by, in: :query, type: :string, required: false,
                description: <<~DESC
                  Field to order projekts by. Valid values:
                  'created_at', 'total_duration_start', 'total_duration_end',
                  'order_number', 'name', 'published_at', 'page_title'.

                  - 'name': the projekt's internal name (case-insensitive A–Z).
                  - 'page_title': the public-facing page title, ordered by the German (de) title, case-insensitive. This is the title shown to users; prefer it over 'name' for display ordering.

                  Projekts with a null value for the chosen field (e.g. no page title, or an unset publish date) are always placed last, in both directions. Invalid values fall back to 'created_at'.

                  **Default:** 'created_at'.
                DESC
      parameter name: :sort_direction, in: :query, type: :string, required: false,
                description: <<~DESC
                  Sort direction for 'sort_by'. Valid values: 'asc', 'desc'. Combine 'sort_by=total_duration_end' with 'sort_direction=asc' to list the projekts expiring next first.

                  **Default:** 'asc'.
                DESC
      parameter name: :only_public, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  If false, returns all projekts (admin only); true returns only activated projekts with published pages shown in overview. Users with public_data access can only access public projekts.

                  **Default:** true (only public projekts).
                DESC
      parameter name: :include_phases, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  If true, includes projekt phases in response with full phase details including type, active status, and dates. Users with public_data access will only see phases that are: visible to frontend (frontend_visibility=true), active, and within the current date range. Admin users see all phases.

                  **Default:** false (excludes phases).
                DESC
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  If true, includes content blocks in response with HTML content organized by locale.

                  **Default:** false (excludes content blocks).
                DESC
      parameter name: :include_text, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  Includes the combined content block body in the response as both text and text_html (the concatenated content block bodies, ordered by position); pass include_text=false to omit them. Always included in the single projekt (show) response.

                  **Default:** true (the fields are included).
                DESC
      parameter name: :include_projekt_settings, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  If true, includes the projekt_settings array (key/value configuration pairs) in the response. Always included in the single projekt (show) response.

                  **Default:** false (the field is omitted).
                DESC
      parameter name: :page, in: :query, type: :integer, required: false,
                description: <<~DESC
                  Pagination page number. When provided, results are paginated and a pagination object is added to the response.

                  **Default:** omitted (all matching projekts are returned, unpaginated).
                DESC
      parameter name: :per_page, in: :query, type: :integer, required: false,
                description: <<~DESC
                  Number of projekts per page when paginating. Only applies when page or per_page is provided.

                  **Default:** 20. **Max:** 2000 (higher values are clamped).
                DESC
      parameter name: :image_variant_versions, in: :query, type: :string, required: false,
                description: <<~DESC
                  Comma-separated list of image variant versions to include in each projekt's page image 'variants' object. Use this to shrink the response payload when only specific sizes are needed (image-variant URL generation is the main serialization cost of this endpoint).

                  Valid versions: '150', '300', '450', '600', '900', '1200', '1920', 'original'. Each numeric version is the image scaled to fit within that maximum width in pixels — height scales proportionally to preserve the aspect ratio, and the image is never upscaled past its original size (so the result may be narrower than the requested width). 'original' is the unmodified upload at its native dimensions. Rough guidance: 150 = thumbnail, 300 = small/mobile, 450–600 = card/body, 900–1200 = wide/desktop header, 1920 = full-bleed/retina hero.

                  Example: 'image_variant_versions=300,900' returns only those two keys. Unknown versions are ignored. Only applies to the list (index) response; the single projekt (show) response always returns all versions.

                  **Default:** all versions are returned.
                DESC

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
                 },
                 pagination: Schemas::Miscellaneous::NO_PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

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
                 },
                 pagination: Schemas::Miscellaneous::NO_PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

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
                 },
                 pagination: Schemas::Miscellaneous::NO_PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '200', 'projekts found sorted by total_duration_end' do
        let(:sort_by) { 'total_duration_end' }
        let(:sort_direction) { 'asc' }

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
                 },
                 pagination: Schemas::Miscellaneous::NO_PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '200', 'projekts found paginated' do
        let(:page) { 1 }
        let(:per_page) { 20 }

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
                 },
                 pagination: Schemas::Miscellaneous::PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

        run_test!
      end

      response '200', 'projekts found with limited image variant versions' do
        let(:image_variant_versions) { '300,900' }

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
                 },
                 pagination: Schemas::Miscellaneous::NO_PAGINATION_RESPONSE_SCHEMA
               },
               required: ['data', 'pagination']

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
                description: <<~DESC
                  If true, includes projekt phases in response with all phases, settings, and configuration. Users with public_data access will only see phases that are: visible to frontend (frontend_visibility=true), active, and within the current date range. Admin users see all phases.

                  **Default:** false (excludes phases).
                DESC
      parameter name: :include_content_blocks, in: :query, type: :boolean, required: false,
                description: <<~DESC
                  If true, includes content blocks in response with all localized content blocks.

                  **Default:** false (excludes content blocks).
                DESC

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

  path '/api/projekts/{id}/update_page_image' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt page image' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Replace the projekt page header/cover image. Provide the image as base64-encoded data under image_attributes. Returns the updated projekt. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :projekt, in: :body, description: 'Projekt image attributes containing the base64-encoded attachment to set as the page image', schema: {
        type: :object,
        properties: {
          projekt: {
            type: :object,
            properties: {
              image_attributes: {
                type: :object,
                description: 'Image to set as the projekt page image. Upload as base64-encoded data.',
                properties: {
                  id: { type: :integer, nullable: true },
                  attachment: { type: :string, description: 'Base64-encoded image file. Required. Supported formats: JPEG, PNG, GIF, WebP (recommended max 5MB).' },
                  title: { type: :string, nullable: true, description: 'Image caption or alt text used for accessibility.' },
                  credits: { type: :string, nullable: true, description: 'Image source attribution or copyright information.' },
                  _destroy: { type: :boolean, nullable: true, description: 'Set to true to remove the current page image.' }
                },
                required: ['attachment']
              }
            },
            required: ['image_attributes']
          }
        },
        required: ['projekt']
      }

      response '200', 'projekt page image updated' do
        let(:test_projekt) { Projekt.create!(name: 'Projekt With Image') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Page Image'
              }
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

      response '422', 'no image provided' do
        let(:test_projekt) { Projekt.create!(name: 'Projekt') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          { projekt: { image_attributes: {} } }
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

      response '403', 'forbidden - admin access required' do
        before do
          api_client.update!(access_level: :public_data)
        end

        let(:test_projekt) { Projekt.create!(name: 'Projekt') }
        let(:id) { test_projekt.id }
        let(:projekt) do
          {
            projekt: {
              image_attributes: {
                attachment: base64_fixture('clippy.png'),
                title: 'Page Image'
              }
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

  path '/api/projekts/{id}/update_settings' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update multiple projekt settings' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]
      description "Bulk-update several projekt settings in a single request. Provide a settings object mapping each existing setting key to its new value. Returns the list of updated keys and a per-key errors map for keys that could not be updated (e.g. unknown keys). #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :settings, in: :body, description: 'Object whose keys are setting keys and whose values are the new setting values', schema: {
        type: :object,
        properties: {
          settings: {
            type: :object,
            description: 'Map of setting key => value. Each key must match an existing projekt setting.',
            additionalProperties: { type: :string },
            example: { 'show_map' => 'true', 'enable_comments' => 'false' }
          }
        },
        required: ['settings']
      }

      response '200', 'settings processed' do
        let(:test_projekt) { Projekt.create!(name: 'Projekt With Settings') }
        let(:id) { test_projekt.id }
        let(:settings) do
          { settings: { 'show_map' => 'true' } }
        end

        before do
          test_projekt.projekt_settings.create!(key: 'show_map', value: 'false')
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     updated: { type: :array, items: { type: :string } },
                     errors: { type: :object }
                   },
                   required: %w[updated errors]
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'settings parameter missing' do
        let(:test_projekt) { Projekt.create!(name: 'Projekt') }
        let(:id) { test_projekt.id }
        let(:settings) { {} }

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


