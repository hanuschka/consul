class NotificationSerializer < BaseSerializer
  attr_reader :projekt_notification

  def initialize(projekt_notification)
    @projekt_notification = projekt_notification
  end

  def serialize
    notification_data = projekt_notification.as_json(
      only: [
        :id,
        :title,
        :body,
        :link_text,
        :link_url,
        :segment_recipient,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if projekt_notification.projekt_phase.present?
      notification_data[:projekt_phase] = {
        id: projekt_notification.projekt_phase.id,
        title: projekt_notification.projekt_phase.phase_tab_name,
        type: projekt_notification.projekt_phase.type,
        projekt_id: projekt_notification.projekt_phase.projekt_id
      }

      if projekt_notification.projekt_phase.projekt.present?
        projekt = projekt_notification.projekt_phase.projekt
        notification_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    notification_data
  end

  def self.serialize_collection(notifications)
    notifications.map { |notification| new(notification).serialize }
  end
end

