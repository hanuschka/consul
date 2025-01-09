module CsvServices
  class DebatesExporter < CsvServices::BaseService
    require "csv"

    def initialize(debates)
      @debates = debates
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @debates.each do |debate|
          csv << row(debate)
        end
      end
    end

    private

      def headers
        [
          "id",
          "title",
          "description",
          "project",
          "category",
          "author",
          "created_at",
          "updated_at",
          "hidden_at",
          "flags_count",
          "ignored_flag_at",
          "cached_votes_total",
          "cached_votes_up",
          "cached_votes_down",
          "comments_count",
          "confirmed_hide_at",
          "cached_anonymous_votes_total",
          "cached_votes_score",
          "hot_score",
          "confidence_score",
          "geozone_id",
          "tsv",
          "featured_at"
        ]
      end

      def row(debate)
        [
          debate.id,
          sanitize_for_csv(debate.title),
          sanitize_for_csv(strip_tags(debate.description)),
          debate.projekt_phase.projekt.name,
          debate.tag_list,
          sanitize_for_csv(debate.author.username),
          debate.created_at,
          debate.updated_at,
          debate.hidden_at,
          debate.flags_count,
          debate.ignored_flag_at,
          debate.cached_votes_total,
          debate.cached_votes_up,
          debate.cached_votes_down,
          debate.comments_count,
          debate.confirmed_hide_at,
          debate.cached_anonymous_votes_total,
          debate.cached_votes_score,
          debate.hot_score,
          debate.confidence_score,
          debate.geozone_id,
          debate.featured_at
        ]
      end
  end
end
