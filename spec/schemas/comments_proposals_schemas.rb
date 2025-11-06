# frozen_string_literal: true

module Schemas
  module CommentsProposals
    COMMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the comment', example: 1 },
        body: { type: :string, description: 'The text content of the comment', example: 'This is a helpful comment on the proposal.' },
        user_id: { type: :integer, nullable: true, description: 'ID of the user who posted the comment', example: 15 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was created', example: '2024-01-20T09:15:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the comment was last modified', example: '2024-01-20T10:30:00Z' },
        parent_id: { type: :integer, nullable: true, description: 'ID of the parent comment if this is a reply. Null for root comments.', example: 5 },
        ancestry: { type: :string, nullable: true, description: 'Ancestry path for nested comment hierarchy (auto-maintained)', example: '5/42' },
        commentable_type: { type: :string, description: 'The type of resource being commented on (e.g., ProjektPhase, Proposal)', example: 'ProjektPhase' },
        commentable_id: { type: :integer, description: 'The ID of the resource being commented on', example: 10 }
      },
      required: %w[id body created_at updated_at commentable_type commentable_id]
    }.freeze

    PROPOSAL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the proposal', example: 1 },
        title: { type: :string, description: 'The title of the proposal', example: 'Green Energy Initiative' },
        description: { type: :string, nullable: true, description: 'Detailed description of the proposal and its goals', example: 'Implement renewable energy across public buildings' },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who created the proposal', example: 20 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was created', example: '2024-01-15T12:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the proposal was last modified', example: '2024-01-18T15:45:00Z' },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this proposal belongs to', example: 25 },
        status: { type: :string, nullable: true, description: 'Current status of the proposal (e.g., published, archived)', example: 'published' },
        comments_count: { type: :integer, nullable: true, description: 'Total number of comments on the proposal', example: 12 }
      },
      required: %w[id created_at updated_at]
    }.freeze

    def self.all
      {
        Comment: COMMENT_SCHEMA,
        Proposal: PROPOSAL_SCHEMA
      }
    end
  end
end
