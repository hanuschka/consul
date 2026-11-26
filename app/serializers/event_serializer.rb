class EventSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[title description location].freeze

  attr_reader :projekt_event

  def initialize(projekt_event, client: nil, registration_counts: nil)
    @projekt_event = projekt_event
    @client = client
    @registration_counts = registration_counts
  end

  def serialize
    event_data = projekt_event.as_json(
      only: [
        :id,
        :title,
        :description,
        :summary,
        :datetime,
        :end_datetime,
        :location,
        :weblink,
        :open_ended,
        :language,
        :projekt_phase_id,
        :registration_enabled,
        :max_attendees,
        :created_at,
        :updated_at
      ]
    )

    event_data[:translations] = serialize_translations(projekt_event, TRANSLATED_ATTRIBUTES)
    event_data[:registrations] = serialize_registration_counts

    if admin_client?
      event_data.merge!(
        confirmation_email_text: projekt_event.confirmation_email_text,
        waitlist_email_text: projekt_event.waitlist_email_text
      )
    end

    event_data[:accessibility] = {
      wheelchair_accessible: projekt_event.wheelchair_accessible,
      accessible_toilet: projekt_event.accessible_toilet,
      disabled_parking_nearby: projekt_event.disabled_parking_nearby,
      tactile_guidance_systems: projekt_event.tactile_guidance_systems,
      induction_loop_available: projekt_event.induction_loop_available,
      assistance_dogs_welcome: projekt_event.assistance_dogs_welcome,
      sign_language_interpreter: projekt_event.sign_language_interpreter
    }

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

    if projekt_event.respond_to?(:image) && projekt_event.image.present?
      serialized_image = ImageSerializer.new(projekt_event.image, include_variants: false).serialize
      event_data[:image] = serialized_image if serialized_image.present?
    end

    event_data
  end

  def self.serialize_collection(events, client: nil)
    counts = registration_counts_by_event(events.map(&:id))

    events.map do |event|
      new(event, client: client, registration_counts: counts.fetch(event.id, {})).serialize
    end
  end

  def self.registration_counts_by_event(event_ids)
    grouped_counts =
      ProjektEventRegistration
        .where(projekt_event_id: event_ids)
        .group(:projekt_event_id, :status)
        .count

    grouped_counts.each_with_object({}) do |((event_id, status), count), counts|
      counts[event_id] ||= {}
      counts[event_id][status] = count
    end
  end

  private

    def registration_counts
      @registration_counts ||=
        self.class.registration_counts_by_event([projekt_event.id]).fetch(projekt_event.id, {})
    end

    def serialize_registration_counts
      confirmed_count = registration_counts.fetch("confirmed", 0)

      registration_data = {
        confirmed_count: confirmed_count,
        spots_available: spots_available(confirmed_count)
      }

      if admin_client?
        registration_data.merge!(
          waitlisted_count: registration_counts.fetch("waitlisted", 0),
          pending_confirmation_count: registration_counts.fetch("pending_confirmation", 0)
        )
      end

      registration_data
    end

    def spots_available(confirmed_count)
      return nil if projekt_event.max_attendees.blank?

      [projekt_event.max_attendees - confirmed_count, 0].max
    end
end
