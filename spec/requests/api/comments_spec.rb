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

  def create_proposal
    projekt = Projekt.create!(name: 'Projekt For Proposal Comments')
    phase = projekt.projekt_phases.create!(type: 'ProjektPhase::ProposalPhase', active: true, phase_tab_name: 'Proposals')

    Proposal.create!(
      author: api_client.user,
      projekt_phase: phase,
      geozone: Geozone.create!(name: "Zone #{SecureRandom.hex(2)}"),
      responsible_name: 'John Doe',
      resource_terms: true,
      title: 'Proposal to comment on',
      description: 'Proposal description'
    )
  end

  def create_budget_investment
    budget = Budget.create!(name: "Budget #{SecureRandom.hex(2)}", currency_symbol: '€')
    group = budget.create_group!(name: "Group #{SecureRandom.hex(2)}")
    heading = group.create_heading!(name: "Heading #{SecureRandom.hex(2)}", price: 1000000)

    Budget::Investment.create!(
      author: api_client.user,
      heading: heading,
      budget: budget,
      resource_terms: true,
      title: 'Investment to comment on',
      description: 'Investment description'
    )
  end

  def self.create_comment_body_parameter
    parameter name: :comment, in: :body, description: 'Comment with its body and an optional parent_id for a reply', schema: {
      type: :object,
      properties: {
        comment: {
          type: :object,
          properties: {
            body: { type: :string, description: 'Text content of the comment' },
            parent_id: { type: :integer, nullable: true, description: 'Optional: ID of a comment on the same resource to reply to' }
          },
          required: %w[body]
        }
      },
      required: ['comment']
    }
  end

  def self.comment_created_schema
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
  end

  path '/api/projekt_phases/{projekt_phase_id}/comments' do
    parameter name: :projekt_phase_id, in: :path, type: :integer, description: 'Projekt Phase ID (CommentPhase)'

    get 'List comments for a projekt phase' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all root-level comments for a projekt phase. Comments support nested replies (children). Returns paginated results with comment hierarchy information. Can be filtered by phase to see all discussion within that phase. Internal valuation comments are only returned to admin clients, marked with internal: true. #{ApiAccessRequirements::GET_READ_ONLY}"
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

  path '/api/proposals/{proposal_id}/comments' do
    parameter name: :proposal_id, in: :path, type: :integer, description: 'Proposal ID'

    post 'Create a comment on a proposal' do
      tags 'Comments'
      produces 'application/json'
      consumes 'application/json'
      security [bearer_auth: []]
      description "Create a comment on a proposal, shown in the proposal's discussion. To reply, send the parent_id of a comment on the same proposal; a parent from another resource returns 422. A body without a `comment` object returns 400. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      create_comment_body_parameter

      response '201', 'comment created on the proposal' do
        let(:proposal) { create_proposal }
        let(:proposal_id) { proposal.id }
        let(:comment) { { comment: { body: 'Comment on a proposal' } } }

        comment_created_schema

        run_test! do |response|
          commentable = JSON.parse(response.body)['data']['comment']['commentable']

          expect(commentable).to include('id' => proposal.id, 'type' => 'Proposal')
          expect(proposal.comments.count).to eq(1)
        end
      end

      response '422', 'parent comment belongs to a different resource' do
        let(:proposal_id) { create_proposal.id }
        let(:phase_comment) do
          Comment.create!(user: api_client.user, commentable: create_phase_with_context[1], body: 'Phase comment')
        end
        let(:comment) { { comment: { body: 'Misplaced reply', parent_id: phase_comment.id } } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end

      response '400', 'comment object missing' do
        let(:proposal_id) { create_proposal.id }
        let(:comment) { {} }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test! do |response|
          expect(JSON.parse(response.body)['error']['type']).to eq('bad_request')
        end
      end

      response '404', 'proposal not found' do
        let(:proposal_id) { 999999 }
        let(:comment) { { comment: { body: 'Comment' } } }

        run_test!
      end

      unauthorized_response { let(:proposal_id) { 1 } }
      forbidden_response { let(:proposal_id) { create_proposal.id } }
    end
  end

  path '/api/budget_investments/{budget_investment_id}/comments' do
    parameter name: :budget_investment_id, in: :path, type: :integer, description: 'Budget investment ID'

    post 'Create a comment on a budget investment' do
      tags 'Comments'
      produces 'application/json'
      consumes 'application/json'
      security [bearer_auth: []]
      description "Create a comment on a budget investment, shown in the investment's discussion. To reply, send the parent_id of a comment on the same investment; a parent from another resource returns 422. A body without a `comment` object returns 400. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      create_comment_body_parameter

      response '201', 'comment created on the budget investment' do
        let(:budget_investment) { create_budget_investment }
        let(:budget_investment_id) { budget_investment.id }
        let(:comment) { { comment: { body: 'Comment on an investment' } } }

        comment_created_schema

        run_test! do |response|
          commentable = JSON.parse(response.body)['data']['comment']['commentable']

          expect(commentable).to include('id' => budget_investment.id, 'type' => 'Budget::Investment')
        end
      end

      response '404', 'budget investment not found' do
        let(:budget_investment_id) { 999999 }
        let(:comment) { { comment: { body: 'Comment' } } }

        run_test!
      end

      unauthorized_response { let(:budget_investment_id) { 1 } }
      forbidden_response { let(:budget_investment_id) { create_budget_investment.id } }
    end
  end

  path '/api/comments' do
    get 'List all comments' do
      tags 'Comments'
      produces 'application/json'
      security [bearer_auth: []]
      description "Retrieve all comments across all projekt phases. Returns a paginated list of root-level comments from all phases. Useful for moderation, analytics, and global discussion oversight. Read-only clients only get comments on projekt phases that are visible and active. Internal valuation comments are only returned to admin clients, marked with internal: true. #{ApiAccessRequirements::GET_READ_ONLY}"
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
      description "Retrieve a comment by ID. The response includes: (1) parent_comment reference if this comment is a reply, (2) child_comments array containing all direct replies to this comment. This enables clients to reconstruct the full comment thread hierarchy. user_id, also on parent_comment, is only returned to admin clients. Read-only clients get 404 for an internal valuation comment and for any comment that is not on a visible, active projekt phase, and never see internal replies or parents. #{ApiAccessRequirements::GET_READ_ONLY}"

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

    patch 'Update a comment' do
      tags 'Comments'
      produces 'application/json'
      consumes 'application/json'
      security [bearer_auth: []]
      description "Change the body of a comment. Its place in the thread and the resource it belongs to stay as they are. A body without a `comment` object returns 400. #{ApiAccessRequirements::ADMIN_REQUIRED}"

      parameter name: :comment, in: :body, description: 'New comment body', schema: {
        type: :object,
        properties: {
          comment: {
            type: :object,
            properties: {
              body: { type: :string, description: 'New text content of the comment' }
            },
            required: %w[body]
          }
        },
        required: ['comment']
      }

      response '200', 'comment updated' do
        let(:comment_record) do
          Comment.create!(user: api_client.user, commentable: create_phase_with_context[1], body: 'Original body')
        end
        let(:id) { comment_record.id }
        let(:comment) { { comment: { body: 'Corrected body' } } }

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

        run_test! do
          expect(comment_record.reload.body).to eq('Corrected body')
        end
      end

      response '422', 'invalid comment' do
        let(:comment_record) do
          Comment.create!(user: api_client.user, commentable: create_phase_with_context[1], body: 'Original body')
        end
        let(:id) { comment_record.id }
        let(:comment) { { comment: { body: '' } } }

        schema ApiResponseExamples::ERROR_SCHEMA

        run_test!
      end

      response '404', 'comment not found' do
        let(:id) { 999999 }
        let(:comment) { { comment: { body: 'Corrected body' } } }

        run_test!
      end

      unauthorized_response { let(:id) { 1 } }
      forbidden_response do
        let(:id) do
          Comment.create!(user: api_client.user, commentable: create_phase_with_context[1], body: 'Body').id
        end
      end
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
