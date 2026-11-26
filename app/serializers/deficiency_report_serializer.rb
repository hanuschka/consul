class DeficiencyReportSerializer < BaseSerializer
  PUBLIC_TRANSLATED_ATTRIBUTES = %w[title description summary official_answer].freeze
  ADMIN_TRANSLATED_ATTRIBUTES = (PUBLIC_TRANSLATED_ATTRIBUTES + %w[reporter_answer]).freeze

  include Rails.application.routes.url_helpers

  attr_reader :deficiency_report

  def initialize(deficiency_report, client: nil)
    @deficiency_report = deficiency_report
    @client = client
  end

  def serialize
    report_data = deficiency_report.as_json(
      only: [
        :id,
        :cached_votes_up,
        :cached_votes_down,
        :cached_votes_total,
        :cached_votes_score,
        :comments_count,
        :created_at,
        :updated_at,
        :video_url,
        :status_changed_at,
        :archived_at,
        :deficiency_report_category_id,
        :deficiency_report_subcategory_id,
        :deficiency_report_status_id
      ]
    )

    report_data.merge!(
      title: deficiency_report.title,
      description: deficiency_report.description,
      summary: deficiency_report.summary,
      official_answer: deficiency_report.official_answer,
      translations: serialize_translations(deficiency_report, translated_attribute_names)
    )

    if admin_client?
      report_data.merge!(
        author_id: deficiency_report.author_id,
        on_behalf_of: deficiency_report.on_behalf_of,
        reporter_answer: deficiency_report.reporter_answer,
        admin_accepted: deficiency_report.admin_accepted,
        assigned_at: deficiency_report.assigned_at,
        deficiency_report_intake_channel_id: deficiency_report.deficiency_report_intake_channel_id,
        intake_channel: serialize_intake_channel
      )
    end

    report_data[:code] = deficiency_report.code

    if deficiency_report.author.present?
      report_data[:author] = serialize_on_behalf_of_author(deficiency_report)
    end

    if deficiency_report.category.present?
      report_data[:category] = {
        id: deficiency_report.category.id,
        name: deficiency_report.category.name,
        icon: deficiency_report.category.icon,
        color: deficiency_report.category.color,
        warning_text: deficiency_report.category.warning_text
      }
    end

    if deficiency_report.subcategory.present?
      report_data[:subcategory] = {
        id: deficiency_report.subcategory.id,
        name: deficiency_report.subcategory.name
      }
    end

    if deficiency_report.status.present?
      report_data[:status] = {
        id: deficiency_report.status.id,
        title: deficiency_report.status.title,
        color: deficiency_report.status.color,
        icon: deficiency_report.status.icon,
        archive_reports: deficiency_report.status.archive_reports
      }
    end

    if admin_client? && deficiency_report.responsible.present?
      report_data[:responsible] = {
        id: deficiency_report.responsible.id,
        type: deficiency_report.responsible_type,
        name: deficiency_report.responsible.name
      }
    end

    report_data[:map_location] = serialize_map_location(deficiency_report.map_location)
    report_data[:tags] = deficiency_report.tags.map(&:name)

    if deficiency_report.image.present?
      serialized_image = ImageSerializer.new(deficiency_report.image, include_variants: true).serialize
      report_data[:image] = serialized_image if serialized_image.present?
    end

    report_data[:documents] = DocumentSerializer.serialize_collection(deficiency_report.documents)
    report_data[:official_answer_documents] = serialize_official_answer_documents

    report_data
  end

  def self.serialize_collection(deficiency_reports, client: nil)
    deficiency_reports.map { |report| new(report, client: client).serialize }
  end

  private

    def translated_attribute_names
      if admin_client?
        ADMIN_TRANSLATED_ATTRIBUTES
      else
        PUBLIC_TRANSLATED_ATTRIBUTES
      end
    end

    def serialize_intake_channel
      return if deficiency_report.intake_channel.blank?

      { id: deficiency_report.intake_channel.id, name: deficiency_report.intake_channel.name }
    end

    def serialize_official_answer_documents
      deficiency_report.official_answer_documents.map do |attachment|
        {
          id: attachment.id,
          filename: attachment.filename.to_s,
          content_type: attachment.content_type,
          byte_size: attachment.byte_size,
          url: rails_blob_url(attachment, **UrlOptions.default)
        }
      end
    end
end
