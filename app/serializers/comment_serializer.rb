# frozen_string_literal: true

class CommentSerializer < BaseSerializer
  attr_reader :comment, :include_children

  def initialize(comment, client: nil, include_children: true)
    @comment = comment
    @client = client
    @include_children = include_children
  end

  def serialize
    comment_data = comment.as_json(
      only: [
        :id,
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

    if admin_client?
      comment_data.merge!(
        user_id: comment.user_id,
        internal: comment.valuation
      )
    end

    if comment.user.present?
      comment_data[:author] = serialize_author(comment.user)
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

    parent_comment = comment.parent

    if parent_comment.present? && visible_to_client?(parent_comment)
      comment_data[:parent_comment] = {
        id: parent_comment.id,
        body: parent_comment.body,
        created_at: parent_comment.created_at,
        updated_at: parent_comment.updated_at
      }

      if admin_client?
        comment_data[:parent_comment][:user_id] = parent_comment.user_id
      end

      if parent_comment.user.present?
        comment_data[:parent_comment][:author] = serialize_author(parent_comment.user)
      end
    end

    child_comments = include_children ? visible_child_comments : []

    if child_comments.any?
      comment_data[:child_comments] = child_comments.map do |child|
        CommentSerializer.new(child, client: client, include_children: false).serialize
      end
    end

    comment_data
  end

  def self.serialize_collection(comments, client: nil)
    comments.map { |comment| new(comment, client: client).serialize }
  end

  private

    def visible_to_client?(other_comment)
      admin_client? || !other_comment.valuation
    end

    def visible_child_comments
      return [] if !comment.respond_to?(:children)

      children = comment.children.includes(user: :organization)

      if admin_client?
        children.to_a
      else
        children.not_valuations.to_a
      end
    end
end
