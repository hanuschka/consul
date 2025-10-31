class ProjektEventSerializer < BaseSerializer
  attr_reader :projekt_event

  def initialize(projekt_event)
    @projekt_event = projekt_event
  end

  def serialize
    event_data = projekt_event.as_json(
      only: [
        :id,
        :title,
        :description,
        :datetime,
        :end_datetime,
        :location,
        :registration_url,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if projekt_event.projekt_phase.present?
      event_data[:projekt_phase] = {
        id: projekt_event.projekt_phase.id,
        title: projekt_event.projekt_phase.phase_tab_name,
        type: projekt_event.projekt_phase.type,
        projekt_id: projekt_event.projekt_phase.projekt_id
      }

      if projekt_event.projekt_phase.projekt.present?
        projekt = projekt_event.projekt_phase.projekt
        event_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if projekt_event.respond_to?(:image) && projekt_event.image.present? && projekt_event.image.attached?
      event_data[:image_url] = projekt_event.image.url
    end

    event_data
  end

  def self.serialize_collection(events)
    events.map { |event| new(event).serialize }
  end
end

