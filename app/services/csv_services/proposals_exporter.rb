module CsvServices
  class ProposalsExporter < CsvServices::BaseService
    require "csv"

    def initialize(proposals)
      @proposals = proposals
    end

    def call
      CSV.generate(headers: true, encoding: "UTF-8") do |csv|
        csv << headers

        @proposals.each do |proposal|
          csv << row(proposal)
        end
      end
    end

    private

      def headers
        [
          "id",
          "title",
          "summary",
          "description",
          "project",
          "label(s)",
          "responsible_name",
          "author_username",
          "supports",
          "created_at",
          "hidden_at",
          "flags_count",
          "comments_count",
          "hot_score",
          "video_url",
          "retired_at",
          "retired_reason",
          "published_at",
          "community_id",
          "selected",
          "latitude",
          "longitude"
        ]
      end

      def row(proposal)
        [
          proposal.id,
          sanitize_for_csv(proposal.title),
          sanitize_for_csv(proposal.summary),
          sanitize_for_csv(strip_tags(proposal.description)),
          proposal.projekt_phase.projekt.name,
          proposal.projekt_labels&.map(&:name)&.join(" "),
          sanitize_for_csv(proposal.responsible_name),
          sanitize_for_csv(proposal.author.username),
          proposal.total_votes,
          proposal.created_at,
          proposal.hidden_at,
          proposal.flags_count,
          proposal.comments_count,
          proposal.hot_score,
          sanitize_for_csv(proposal.video_url),
          proposal.retired_at,
          sanitize_for_csv(proposal.retired_reason),
          proposal.published_at,
          proposal.community_id,
          proposal.selected,
          geo_field(proposal.map_location&.latitude),
          geo_field(proposal.map_location&.longitude)
        ]
      end

      def geo_field(field)
        return nil if field.blank?

        "\"#{field}\""
      end
  end
end
