class Proposal::CsvExporter
  require "csv"
  include JsonExporter

  def initialize(proposals)
    @proposals = proposals
  end

  def to_csv
    CSV.generate(headers: true) do |csv|
      csv << headers

      @proposals.each do |proposal|
        csv << csv_values(proposal)
      end
    end
  end

  def model
    Proposal
  end

  private

    def headers
        # I18n.t("admin.proposals.index.list.id"),
      [
        "id",
        "responsible_name",
        "author_username",
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
        "projekt_id"
      ]
    end

    def csv_values(proposal)
      [
        proposal.id.to_s,
        proposal.responsible_name,
        proposal.author.username,
        proposal.created_at,
        proposal.hidden_at,
        proposal.flags_count,
        proposal.comments_count,
        proposal.hot_score,
        proposal.video_url,
        proposal.retired_at,
        proposal.retired_reason,
        proposal.published_at,
        proposal.community_id,
        proposal.selected,
        proposal.projekt_id
      ]
    end
end
