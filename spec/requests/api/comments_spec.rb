# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Comments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { ApiClient.create!(name: 'Test Client', registration_status: :registered, access_level: :admin).tap(&:reload) }
  let(:Authorization) { "Bearer #{api_client.auth_token}" }

  def create_phase_with_context
    projekt = Projekt.create!(name: 'Projekt For Comments')
    phase = projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true, phase_tab_name: 'Comments')
    [projekt, phase]
  end

  path '/api/projekt_phases/{projekt_phase_id}/comments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (CommentPhase)'

    get 'List comments for a projekt phase' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page (default 100)'

      response '200', 'comments found' do
        before do
          _projekt, phase = create_phase_with_context
          2.times do |i|
            comment = Comment.new(
              user: api_client.user,
              commentable: phase,
              translations_attributes: [
                {
                  locale: 'en',
                  body: "Comment #{i + 1}"
                }
              ]
            )
            comment.save!
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comments: { type: :array, items: { type: :object } }
                   },
                   required: ['comments']
                 },
                 pagination: { type: :object }
               },
               required: ['data']

        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let(:projekt) { Projekt.create!(name: 'Projekt For Comments') }
        let(:phase) { projekt.projekt_phases.create!(type: 'ProjektPhase::CommentPhase', active: true) }
        let(:projekt_phase_id) { phase.id }

        before do
          phase # Ensure phase is created
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end
    end

    post 'Create a comment' do
      tags 'Comments'
      produces 'application/json'
      consumes 'application/json'
      security [bearer_auth: []]
      parameter name: :comment, in: :body, description: 'Comment creation payload', schema: {
        type: :object,
        properties: {
          comment: {
            type: :object,
            properties: {
              body: { type: :string },
              parent_id: { type: :integer, nullable: true },
              ancestry: { type: :string, nullable: true }
            },
            required: %w[body]
          }
        },
        required: ['comment']
      }

      response '201', 'comment created' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              translations_attributes: [
                {
                  locale: 'en',
                  body: 'This is a new comment'
                }
              ]
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comment: { type: :object }
                   },
                   required: ['comment']
                 }
               },
               required: ['data']

        run_test!
      end

      response '422', 'invalid request' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              translations_attributes: [
                {
                  locale: 'en',
                  body: ''
                }
              ]
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

      response '403', 'forbidden - admin access required' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              translations_attributes: [
                {
                  locale: 'en',
                  body: 'Test comment'
                }
              ]
            }
          }
        end

        before do
          api_client.update_column(:access_level, :public_data)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
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

  path '/api/comments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Comment ID'

    get 'Retrieve a comment' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]

      response '200', 'comment found' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            translations_attributes: [
              {
                locale: 'en',
                body: 'Test comment'
              }
            ]
          )
          comment.save!
          comment
        end
        let(:id) { comment_record.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comment: { type: :object }
                   },
                   required: ['comment']
                 }
               },
               required: ['data']

        run_test!
      end

      response '404', 'comment not found' do
        let(:id) { 999999 }
        run_test!
      end

      response '403', 'forbidden - insufficient access' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            translations_attributes: [
              {
                locale: 'en',
                body: 'Test comment'
              }
            ]
          )
          comment.save!
          comment
        end
        let(:id) { comment_record.id }

        before do
          comment_record # Ensure comment is created
          api_client.update_column(:access_level, nil)
        end

        schema type: :object,
               properties: {
                 error: {
                   type: :object,
                   properties: {
                     type: { type: :string },
                     messages: { type: :string }
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
