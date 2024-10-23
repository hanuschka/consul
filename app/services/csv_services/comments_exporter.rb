module CsvServices
  class CommentsExporter < ApplicationService
    require "csv"

    def initialize(comments)
      @comments = comments
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @comments.each do |comment|
          csv << row(comment)
        end
      end
    end

    private

      def headers
        [
          "ID", "body", "cached_votes_total", "cached_votes_up", "cached_votes_down",
          "author_username", "author_user_id", "author_email",
          "commentable_type", "commentable_id",
          "flags_count", "ignored_flag_at", "moderator_id",
          "hidden_at",
          "created_at"
        ]
      end

      def row(comment)
        [
          comment.id, comment.body, comment.cached_votes_total, comment.cached_votes_up, comment.cached_votes_down,
          comment.author&.username, comment.user_id, comment.author&.email,
          comment.commentable_type, comment.commentable_id,
          comment.flags_count, comment.ignored_flag_at, comment.moderator_id,
          comment.hidden_at,
          I18n.l(comment.created_at, format: "%d.%m.%Y")
        ]
      end
  end
end
