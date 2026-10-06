# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Comments API', type: :request, openapi_spec: 'v1/swagger.yaml' do
  let!(:api_client) { create_api_client }
  let(:Authorization) { "Bearer #{api_client.access_token}" }

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
      description "Retrieve all root-level comments for a projekt phase. Comments support nested replies (children). Returns paginated results with comment hierarchy information. Can be filtered by phase to see all discussion within that phase. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :sort, in: :query, type: :string, required: false, description: "Sort comments by. Valid values: 'oldest' (**default**, oldest comments first), 'newest' (newest comments first), 'most_voted' (highest voted first, then oldest)"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 5000, max: 5000)'

      response '200', 'comments found and returned' do
        before do
          _projekt, phase = create_phase_with_context
          2.times do |i|
            comment = Comment.new(
              user: api_client.user,
              commentable: phase,
              body: "Comment #{i + 1}"
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
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '200', 'comments sorted by newest first' do
        before do
          _projekt, phase = create_phase_with_context
          2.times do |i|
            comment = Comment.new(
              user: api_client.user,
              commentable: phase,
              body: "Comment #{i + 1}"
            )
            comment.save!
          end
        end

        let(:projekt_phase_id) { ProjektPhase.last.id }
        let(:sort) { 'newest' }

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

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end

    post 'Create a comment' do
      tags 'Comments'
      produces 'application/json'
      consumes 'application/json'
      security [bearer_auth: []]
      description "Create a new comment on a projekt phase. Supports both root-level comments and nested replies. To create a reply, specify the parent_id of the comment being responded to. Root comments do not have a parent_id. Comments support rich HTML content and are moderated by administrators. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :comment, in: :body, description: 'Comment data with required body text and optional parent_id for nested replies', schema: {
        type: :object,
        properties: {
          comment: {
            type: :object,
            properties: {
              body: { type: :string, description: 'Text content of the comment' },
              parent_id: { type: :integer, nullable: true, description: 'Optional: ID of parent comment for replies. If provided, creates a nested reply.' },
              ancestry: { type: :string, nullable: true, description: 'Ancestry string for hierarchy (auto-generated)' }
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
              body: 'This is a new comment'
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

      response '201', 'comment reply created successfully' do
        let!(:context) { create_phase_with_context }
        let(:parent_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'This is the parent comment that will be replied to'
          )
          comment.save!
          comment
        end
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: 'This is a reply to the parent comment',
              parent_id: parent_comment.id
            }
          }
        end

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comment: {
                       type: :object,
                       description: 'Serialized comment reply with parent_comment reference and ancestry information'
                     }
                   },
                   required: ['comment']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          comment_data = data['data']['comment']
          expect(comment_data['parent_comment']).to be_a(Hash)
          expect(comment_data['parent_comment']['id']).to eq(parent_comment.id)
        end
      end

      response '201', 'nested reply to a reply' do
        let!(:context) { create_phase_with_context }
        let(:root_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Root comment'
          )
          comment.save!
          comment
        end
        let(:parent_reply) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Reply to root',
            parent: root_comment
          )
          comment.save!
          comment
        end
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: 'Reply to a reply (nested deeper)',
              parent_id: parent_reply.id
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

        run_test! do |response|
          data = JSON.parse(response.body)
          comment_data = data['data']['comment']
          expect(comment_data['parent_comment']).to be_a(Hash)
          expect(comment_data['parent_comment']['id']).to eq(parent_reply.id)
        end
      end

      response '422', 'invalid request' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: ''
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

      response '422', 'invalid reply - empty body' do
        let!(:context) { create_phase_with_context }
        let(:parent_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Parent comment'
          )
          comment.save!
          comment
        end
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: '',
              parent_id: parent_comment.id
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

      response '404', 'invalid reply - parent comment not found' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: 'Reply to non-existent parent',
              parent_id: 999999
            }
          }
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        let!(:context) { create_phase_with_context }
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: 'Test comment'
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
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      response '403', 'forbidden - admin access required for replies' do
        let!(:context) { create_phase_with_context }
        let(:parent_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Parent comment'
          )
          comment.save!
          comment
        end
        let(:projekt_phase_id) { context[1].id }
        let(:comment) do
          {
            comment: {
              body: 'This reply requires admin access',
              parent_id: parent_comment.id
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
                     messages: { type: :array, items: { type: :string } }
                   }
                 }
               }

        run_test! do |response|
          data = JSON.parse(response.body)
          expect(data['error']['type']).to eq('forbidden')
        end
      end

      unauthorized_response { let(:projekt_phase_id) { 1 } }
    end
  end

  path '/api/comments' do
    get 'List all comments' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all comments across all projekt phases. Returns a paginated list of root-level comments from all phases. Useful for moderation, analytics, and global discussion oversight. #{ApiAccessRequirements::GET_READ_ONLY}"
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Pagination page number (**default:** 1)'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Number of items per page (**default:** 5000, max: 5000)'

      response '200', 'comments found and returned' do
        before do
          projekt1, phase1 = create_phase_with_context
          projekt2, phase2 = create_phase_with_context
          2.times do |i|
            comment = Comment.new(
              user: api_client.user,
              commentable: phase1,
              body: "Comment #{i + 1} from phase 1"
            )
            comment.save!
          end
          comment = Comment.new(
            user: api_client.user,
            commentable: phase2,
            body: "Comment from phase 2"
          )
          comment.save!
        end

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

      unauthorized_response
    end
  end

  path '/api/comments/{id}' do
    parameter name: :id, in: :path, type: :integer, description: 'Comment ID'

    get 'Retrieve a comment' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve a comment by ID. The response includes: (1) parent_comment reference if this comment is a reply, (2) child_comments array containing all direct replies to this comment. This enables clients to reconstruct the full comment thread hierarchy. #{ApiAccessRequirements::GET_READ_ONLY}"

      response '200', 'comment found' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Test comment'
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

      response '200', 'root comment with child comments returned' do
        let!(:context) { create_phase_with_context }
        let(:root_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Root comment with replies'
          )
          comment.save!
          2.times do |i|
            child = Comment.new(
              user: api_client.user,
              commentable: context[1],
              body: "Reply #{i + 1}",
              parent: comment
            )
            child.save!
          end
          comment
        end
        let(:id) { root_comment.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comment: {
                       type: :object,
                       properties: {
                         id: { type: :integer },
                         body: { type: :string },
                         parent_comment: { type: :object, nullable: true, description: 'Parent comment (null for root comments)' },
                         child_comments: {
                           type: :array,
                           description: 'Array of direct child comments (replies to this comment)',
                           items: { type: :object }
                         },
                         ancestry: { type: :string, nullable: true, description: 'Ancestry string for comment hierarchy (null for root comments)' }
                       }
                     }
                   },
                   required: ['comment']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          comment_data = data['data']['comment']
          expect(comment_data['child_comments']).to be_an(Array)
          expect(comment_data['child_comments'].length).to eq(2)
          expect(comment_data['parent_comment']).to be_nil
          comment_data['child_comments'].each do |child|
            expect(child['parent_comment']).to be_a(Hash)
            expect(child['parent_comment']['id']).to eq(root_comment.id)
          end
        end
      end

      response '200', 'reply comment with parent reference' do
        let!(:context) { create_phase_with_context }
        let(:parent_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Parent comment'
          )
          comment.save!
          comment
        end
        let(:reply_comment) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'This is a reply',
            parent: parent_comment
          )
          comment.save!
          comment
        end
        let(:id) { reply_comment.id }

        schema type: :object,
               properties: {
                 data: {
                   type: :object,
                   properties: {
                     comment: {
                       type: :object,
                       description: 'Reply comment with parent_comment reference'
                     }
                   },
                   required: ['comment']
                 }
               },
               required: ['data']

        run_test! do |response|
          data = JSON.parse(response.body)
          comment_data = data['data']['comment']
          expect(comment_data['parent_comment']).to be_a(Hash)
          expect(comment_data['parent_comment']['id']).to eq(parent_comment.id)
          expect(comment_data['parent_comment']['body']).to eq('Parent comment')
          expect(comment_data['parent_comment']['author']).to be_a(Hash)
        end
      end

      response '404', 'comment not found' do
        let(:id) { 999999 }
        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
    end

    delete 'Delete a comment' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Delete a comment and all its nested replies from a projekt phase. Deletion is permanent and affects the entire comment thread hierarchy. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      response '200', 'comment deleted successfully' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Comment to delete'
          )
          comment.save!
          comment
        end
        let(:id) { comment_record.id }

        schema type: :object,
               properties: {
                 message: { type: :string }
               },
               required: ['message']

        run_test!
      end

      response '404', 'comment not found' do
        let(:id) { 999999 }

        run_test!
      end

      response '422', 'unable to delete comment' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Comment'
          )
          comment.save!
          comment
        end
        let(:id) { comment_record.id }

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
          allow_any_instance_of(Comment).to receive(:destroy).and_return(false)
          errors_mock = double('errors').as_null_object
          allow(errors_mock).to receive(:messages).and_return({ base: ['Cannot delete comment'] })
          allow_any_instance_of(Comment).to receive(:errors).and_return(errors_mock)
        end

        run_test!
      end

      response '403', 'forbidden - admin access required' do
        let!(:context) { create_phase_with_context }
        let(:comment_record) do
          comment = Comment.new(
            user: api_client.user,
            commentable: context[1],
            body: 'Comment to delete'
          )
          comment.save!
          comment
        end
        let(:id) { comment_record.id }

        before do
          comment_record
          api_client.update_column(:access_level, :public_data)
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
