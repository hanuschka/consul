class Whatsapp::Archive::ListEventsService < ApplicationService
  def initialize(conversation:, projekt: nil)
    @conversation = conversation
    @projekt = projekt
  end

  def call
    ::Whatsapp::Archive::SendDigestService.call(
      conversation: @conversation,
      entries: entries,
      intro: I18n.t("whatsapp.archive.menu.events.intro"),
      empty_body: I18n.t("whatsapp.archive.menu.events.empty")
    )
  end

  private

    # The date leads the description because "which of these is soon" is the
    # only question a list of events has to answer at a glance.
    def entries
      Whatsapp::UpcomingEventsQuery.call(projekt: @projekt).map do |event|
        {
          title: event.title,
          description: description_for(event),
          url: event.weblink.presence || Whatsapp::ProjektLink.phase_url(event.projekt_phase)
        }
      end
    end

    def description_for(event)
      [I18n.l(event.datetime, format: :short), event.location.presence].compact.join(" · ")
    end
end
