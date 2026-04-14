# frozen_string_literal: true

class CommentSerializer < BaseSerializer
  attr_reader :comment, :include_children

  def initialize(comment, include_children: true)
    @comment = comment
    @include_children = include_children
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

    if comment.parent.present?
      parent_comment = comment.parent
      comment_data[:parent_comment] = {
        id: parent_comment.id,
        body: parent_comment.body,
        user_id: parent_comment.user_id,
        created_at: parent_comment.created_at,
        updated_at: parent_comment.updated_at
      }

      if parent_comment.user.present?
        comment_data[:parent_comment][:author] = {
          id: parent_comment.user.id,
          username: parent_comment.user.username,
          public_name: parent_comment.user.public_name
        }
      end
    end

    if include_children && comment.respond_to?(:children) && comment.children.any?
      comment_data[:child_comments] = comment.children.map do |child|
        CommentSerializer.new(child, include_children: false).serialize
      end
    end

    comment_data
  end

  def self.serialize_collection(comments)
    comments.map { |comment| new(comment).serialize }
  end
end
