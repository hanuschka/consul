# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Content Blocks API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  path '/api/projekts/{projekt_id}/content_blocks' do
    parameter name: :projekt_id, in: :path, type: :integer, description: 'Projekt ID'

    get 'List content blocks for a projekt' do
      tags 'Content Blocks'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'content blocks found' do
        let(:projekt) { Projekt.create!(name: 'Projekt With Content Blocks') }
        let(:projekt_id) { projekt.id }

        before do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'block_1',
            locale: 'en',
            body: 'First content block',
            position: 1
          )
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'block_2',
            locale: 'en',
            body: 'Second content block',
            position: 2
          )
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     content_blocks: {
                       type: :array,
                       items: { '$ref' => '#/components/schemas/ContentBlock' }
                     }
                   },
                   required: ['content_blocks']
                 }
               },
               required: ['data']

        run_test!
      end
    end

    post 'Create a content block' do
      tags 'Content Blocks'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :content_block, in: :body, description: 'Content block creation payload', schema: {
        type: :object,
        properties: {
          content_block: {
            type: :object,
            properties: {
              name: { type: :string, example: 'custom' },
              locale: { type: :string, example: 'en' },
              body: { type: :string, nullable: true },
              key: { type: :string, nullable: true },
              position: { type: :integer, nullable: true }
            },
            required: ['name']
          }
        },
        required: ['content_block']
      }

      response '201', 'content block created' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Content Block') }
        let(:projekt_id) { projekt.id }
        let(:content_block) do
          {
            content_block: {
              name: 'custom',
              key: 'test_block',
              locale: 'en',
              body: 'Test content block body',
              position: 1
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     content_block: { '$ref' => '#/components/schemas/ContentBlock' }
                   },
                   required: ['content_block']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Content Block') }
        let(:projekt_id) { projekt.id }
        let(:content_block) do
          {
            content_block: {
              name: ''  # Invalid - name can't be blank
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
    end

    post 'Reorder content blocks' do
      tags 'Content Blocks'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :ordered_ids, in: :body, description: 'Array of content block IDs in desired order', schema: {
        type: :object,
        properties: {
          ordered_ids: {
            type: :array,
            items: { type: :integer },
            description: 'Array of content block IDs in desired order'
          }
        },
        required: ['ordered_ids']
      }

      response '200', 'content blocks reordered successfully' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Reordering') }
        let(:projekt_id) { projekt.id }
        let(:block1) { projekt.content_blocks.create!(name: 'custom', key: 'block_1', locale: 'en', position: 1) }
        let(:block2) { projekt.content_blocks.create!(name: 'custom', key: 'block_2', locale: 'en', position: 2) }
        let(:block3) { projekt.content_blocks.create!(name: 'custom', key: 'block_3', locale: 'en', position: 3) }
        let(:ordered_ids) { { ordered_ids: [block3.id, block1.id, block2.id] } }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Reordering') }
        let(:projekt_id) { projekt.id }
        let(:ordered_ids) { {} }

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

  path '/api/content_blocks/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Content Block ID'

    get 'Retrieve a content block' do
      tags 'Content Blocks'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'content block found' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:content_block) do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'test_block',
            locale: 'en',
            body: 'Test content',
            position: 1
          )
        end
        let(:id) { content_block.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     content_block: { '$ref' => '#/components/schemas/ContentBlock' }
                   },
                   required: ['content_block']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'content block not found' do
        let(:id) { 999999 }

        run_test!
      end
    end

    patch 'Update a content block' do
      tags 'Content Blocks'
      consumes 'application/json'
      produces 'application/json'
      security [bearer_auth: []]

      parameter name: :content_block, in: :body, description: 'Attributes to update on the content block', schema: {
        type: :object,
        properties: {
          content_block: {
            type: :object,
            properties: {
              name: { type: :string, nullable: true },
              locale: { type: :string, nullable: true },
              body: { type: :string, nullable: true },
              key: { type: :string, nullable: true },
              position: { type: :integer, nullable: true }
            }
          }
        },
        required: ['content_block']
      }

      response '200', 'content block updated' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:test_content_block) do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'test_block',
            locale: 'en',
            body: 'Original content',
            position: 1
          )
        end
        let(:id) { test_content_block.id }
        let(:content_block) do
          {
            content_block: {
              body: 'Updated content'
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     content_block: { '$ref' => '#/components/schemas/ContentBlock' }
                   },
                   required: ['content_block']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'content block not found' do
        let(:id) { 999999 }
        let(:content_block) do
          {
            content_block: {
              body: 'Updated content'
            }
          }
        end

        run_test!
      end

      response '422', 'invalid request' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:test_content_block) do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'test_block',
            locale: 'en',
            body: 'Original content',
            position: 1
          )
        end
        let(:id) { test_content_block.id }
        let(:content_block) do
          {
            content_block: {
              name: ''  # Invalid - name can't be blank
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
    end

    delete 'Delete a content block' do
      tags 'Content Blocks'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'content block deleted' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:content_block) do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'test_block',
            locale: 'en',
            body: 'Content to delete',
            position: 1
          )
        end
        let(:id) { content_block.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'content block not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete content block' do
        let(:projekt) { Projekt.create!(name: 'Projekt') }
        let(:content_block) do
          projekt.content_blocks.create!(
            name: 'custom',
            key: 'test_block',
            locale: 'en',
            body: 'Content',
            position: 1
          )
        end
        let(:id) { content_block.id }

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
          allow_any_instance_of(SiteCustomization::ContentBlock).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete content block'] })
          allow_any_instance_of(SiteCustomization::ContentBlock).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end
    end
  end
end
