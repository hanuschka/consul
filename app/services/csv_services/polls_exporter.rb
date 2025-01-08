module CsvServices
  class PollsExporter < CsvServices::BaseService
    require "csv"

    def initialize(polls)
      @polls = polls
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @polls.each do |poll|
          csv << row(poll)
        end
      end
    end

    private

      def headers
        [
          "id",
          "name",
          "project",
          "starts_at",
          "ends_at",
          "published",
          "geozone_restricted",
          "comments_count",
          "hidden_at",
          "slug",
          "created_at",
          "updated_at",
          "budget_id",
          "related_type",
          "related_id"
        ]
      end

      def row(poll)
        [
          poll.id,
          poll.name,
          poll.projekt&.name,
          poll.projekt_phase.start_date,
          poll.projekt_phase.end_date,
          poll.published,
          poll.geozone_restricted,
          poll.comments_count,
          poll.hidden_at,
          poll.slug,
          poll.created_at,
          poll.updated_at,
          poll.budget_id,
          poll.related_type,
          poll.related_id
        ]
      end
  end
end
