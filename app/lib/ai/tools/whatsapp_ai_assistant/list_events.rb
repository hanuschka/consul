class Ai::Tools::WhatsappAiAssistant::ListEvents < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the participation events still to come — date, place and the link to each. " \
              "Name a project for its own dates, or pass null for the whole portal. Past events " \
              "are never returned, so nothing here has happened yet. Returns facts for you to " \
              "answer in your own words — it sends nothing to the citizen itself."

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
  end

  def execute(projekt_name: nil)
    for_named_projekt(projekt_name) do |projekt|
      { events: ::Whatsapp::UpcomingEventsQuery.call(projekt: projekt).map { |event| row_for(event) }}
    end
  end

  private

    # The event's own weblink wins where it has one: an event that lives on the
    # organiser's site is reached there rather than through the phase that lists
    # it.
    def row_for(event)
      {
        title: event.title,
        starts_at: event.datetime&.iso8601,
        location: event.location.presence,
        projekt: projekt_title(event.projekt_phase.projekt),
        url: event.weblink.presence || ::Whatsapp::ProjektLink.phase_url(event.projekt_phase)
      }.compact
    end
end
