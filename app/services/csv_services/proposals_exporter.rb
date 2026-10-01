module CsvServices
  class ProposalsExporter < CsvServices::BaseService
    require "csv"

    COUNT_BATCH_SIZE = 200

    def initialize(proposals)
      @proposals = proposals
    end

    def call
      CSV.generate(headers: true, col_sep: ";", force_quotes: true, encoding: "UTF-8") do |csv|
        csv << headers

        @proposals
          .includes(:image)
          .preload(projekt_phase: [:projekt, :settings])
          .to_a.each_slice(COUNT_BATCH_SIZE) do |batch|
          @similar_contributions_counts = SimilarContributions::StoredCounts.call(batch)

          batch.each { |proposal| csv << row(proposal) }
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
          "sentiment",
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
          "image_ai_generated",
          "district",
          "geometry",
          "similar_contributions"
        ]
      end

      def row(proposal)
        [
          proposal.id,
          sanitize_for_csv(proposal.title),
          sanitize_for_csv(proposal.summary),
          sanitize_for_csv(strip_tags(proposal.description)),
          proposal.projekt_phase.projekt.name,
          proposal.projekt_labels&.map(&:name)&.join(" | "),
          proposal.sentiment&.name,
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
          proposal.image&.ai_generated,
          proposal.district&.name,
          format_geometry(proposal.map_location&.features),
          similar_contributions_count(proposal)
        ]
      end

      def similar_contributions_count(resource)
        @similar_contributions_counts.fetch(resource.id, 0)
      end
  end
end
