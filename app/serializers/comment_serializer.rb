# frozen_string_literal: true

class CommentSerializer < BaseSerializer
  attr_reader :comment

  def initialize(comment)
    @comment = comment
  end

  def serialize
    comment_data = comment.as_json(
      only: [
        :id,
        :user_id,
        :commentable_id,
        :commentable_type,
        :created_at,
        :updated_at,
        :cached_votes_up,
        :cached_votes_down,
        :cached_votes_score,
        :confidence_score,
        :ancestry
      ]
    )

    comment_data.merge!(
      body: comment.body
    )

    if comment.user.present?
      comment_data[:author] = {
        id: comment.user.id,
        username: comment.user.username,
        public_name: comment.user.public_name
      }
    end

    if comment.commentable.present?
      comment_data[:commentable] = {
        id: comment.commentable.id,
        type: comment.commentable_type
      }

      if comment.commentable.respond_to?(:projekt_phase) && comment.commentable.projekt_phase.present?
        comment_data[:projekt_phase] = {
          id: comment.commentable.projekt_phase.id,
          title: comment.commentable.projekt_phase.phase_tab_name,
          type: comment.commentable.projekt_phase.type
        }
      elsif comment.commentable.is_a?(ProjektPhase)
        comment_data[:projekt_phase] = {
          id: comment.commentable.id,
          title: comment.commentable.phase_tab_name,
          type: comment.commentable.type
        }
      end
    end

    comment_data
  end

  def self.serialize_collection(comments)
    comments.map { |comment| new(comment).serialize }
  end
end
