# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Projekts API', type: :request do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin) }
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

      response '403', 'forbidden - insufficient access' do
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
    end

    post 'Create a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt, in: :body, description: 'Projekt creation payload', schema: { '$ref' => '#/components/schemas/ProjektCreateParams' }

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

      response '200', 'projekt found with public_data access' do
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

        let(:test_projekt) { Projekt.create!(name: 'Test Projekt') }
        let(:id) { test_projekt.id }

        run_test!
      end
    end

    patch 'Update a projekt' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt, in: :body, description: 'Attributes to update on the projekt', schema: { '$ref' => '#/components/schemas/ProjektUpdateParams' }

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
    end
  end

  path '/api/projekts/{id}/update_page' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt page attributes (title/subtitle)' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :page, in: :body, description: 'Projekt page attributes', schema: {
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
    end
  end

  path '/api/projekts/{id}/update_image' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt page image' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :image, in: :body, description: 'Image attributes payload. Send attachment (base64-encoded)/title/credits to set/update the image, or _destroy=true to remove it.', schema: { '$ref' => '#/components/schemas/ImageAttributesApi' }

      response '200', 'projekt page image updated' do
        let!(:test_user) do
          user = User.create!(
            username: "admin_user_#{SecureRandom.hex(4)}",
            email: "admin_#{SecureRandom.hex(4)}@example.com",
            password: 'Password1!',
            terms_data_storage: '1',
            terms_data_protection: '1',
            terms_general: '1',
            confirmed_at: Time.current
          )
          Administrator.create!(user: user)
          user
        end
        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:image) do
          # Read fixture image and encode as base64
          image_path = Rails.root.join('spec', 'fixtures', 'files', 'clippy.jpg')
          base64_image = Base64.encode64(File.read(image_path))
          {
            image: {
              attachment: base64_image,
              title: 'Cover Image Title'
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
        let(:image) { {} }

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

        let(:test_projekt) { Projekt.create!(name: 'Original Name') }
        let(:id) { test_projekt.id }
        let(:image) do
          image_path = Rails.root.join('spec', 'fixtures', 'files', 'clippy.jpg')
          base64_image = Base64.encode64(File.read(image_path))
          {
            image: {
              attachment: base64_image,
              title: 'Cover Image Title'
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
    end
  end
  path '/api/projekts/{id}/update_setting' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update a projekt setting' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :setting, in: :body, description: 'Key/value to update on projekt settings', schema: {
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
    end
  end

  path '/api/projekts/{id}/update_body' do
    parameter name: :id, in: :path, type: :integer, description: 'Projekt ID'

    patch 'Update projekt content block body' do
      tags 'Projekts'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :projekt, in: :body, description: 'Content block body update payload', schema: {
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
    end
  end
end


