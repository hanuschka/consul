class DeficiencyReportSerializer < BaseSerializer
  attr_reader :deficiency_report

  def initialize(deficiency_report)
    @deficiency_report = deficiency_report
  end

  def serialize
    report_data = deficiency_report.as_json(
      only: [
        :id,
        :author_id,
        :cached_votes_up,
        :cached_votes_down,
        :cached_votes_total,
        :cached_votes_score,
        :comments_count,
        :hot_score,
        :created_at,
        :updated_at,
        :video_url,
        :on_behalf_of,
        :admin_accepted,
        :assigned_at,
        :status_changed_at,
        :archived_at
      ]
    )

    report_data.merge!(
      title: deficiency_report.title,
      description: deficiency_report.description,
      summary: deficiency_report.summary,
      official_answer: deficiency_report.official_answer
    )

    report_data[:code] = deficiency_report.code

    if deficiency_report.author.present?
      report_data[:author] = {
        id: deficiency_report.author.id,
        username: deficiency_report.author.username,
        public_name: deficiency_report.author.public_name
      }
    end

    if deficiency_report.category.present?
      report_data[:category] = {
        id: deficiency_report.category.id,
        name: deficiency_report.category.name,
        icon: deficiency_report.category.icon,
        color: deficiency_report.category.color
      }
    end

    if deficiency_report.status.present?
      report_data[:status] = {
        id: deficiency_report.status.id,
        title: deficiency_report.status.title,
        color: deficiency_report.status.color,
        archive_reports: deficiency_report.status.archive_reports
      }
    end

    if deficiency_report.responsible.present?
      report_data[:responsible] = {
        id: deficiency_report.responsible.id,
        type: deficiency_report.responsible_type,
        name: deficiency_report.responsible.name
      }
    end

    if deficiency_report.map_location.present?
      report_data[:map_location] = {
        latitude: deficiency_report.map_location.latitude,
        longitude: deficiency_report.map_location.longitude,
        zoom: deficiency_report.map_location.zoom,
        approximated_address: deficiency_report.approximated_address
      }
    end

    report_data[:tags] = deficiency_report.tags.pluck(:name) if deficiency_report.tags.any?

    if deficiency_report.respond_to?(:image) && deficiency_report.image.present?
      serialized_image = ImageSerializer.new(deficiency_report.image, include_variants: false).serialize
      report_data[:image] = serialized_image if serialized_image.present?
    end

    if deficiency_report.respond_to?(:documents) && deficiency_report.documents.any?
      report_data[:documents] = deficiency_report.documents.map do |doc|
        {
          id: doc.id,
          title: doc.title,
          attachment_file_name: doc.attachment_file_name,
          attachment_file_size: doc.attachment_file_size
        }
      end
    end

    report_data
  end

  def self.serialize_collection(deficiency_reports)
    deficiency_reports.map { |report| new(report).serialize }
  end
end

