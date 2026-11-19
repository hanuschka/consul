class DeficiencyReportStatusSerializer < BaseSerializer
  attr_reader :status

  def initialize(status, client: nil)
    @status = status
    @client = client
  end

  def serialize
    status_data = status.as_json(only: [:id, :color, :icon, :given_order, :archive_reports, :created_at, :updated_at])

    status_data.merge!(
      title: status.title,
      description: status.description,
      translations: serialize_translations(status)
    )

    if admin_client?
      status_data.merge!(
        notice_text: status.notice_text,
        reminder_delay: status.reminder_delay
      )
    end

    status_data
  end

  def self.serialize_collection(statuses, client: nil)
    statuses.map { |status| new(status, client: client).serialize }
  end
end
