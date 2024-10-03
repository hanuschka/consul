class Poll::CsvExporter
  require "csv"
  include JsonExporter

  def initialize(polls)
    @polls = polls
  end

  def to_csv
    CSV.generate(headers: true, col_sep: ";") do |csv|
      csv << headers

      @polls.each do |poll|
        csv << csv_values(poll)
      end
    end
  end

  private

    def headers
      [
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

    def csv_values(poll)
      [
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
