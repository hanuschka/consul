class ContentCard::EventsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings['limit'].to_i

    @original_events =
      if custom_page.present?

        ProjektEvent
          .joins(:projekt_phase)
          .where(projekt_phases: {
            active: true,
            projekt_id: custom_page.landing_projekts.activated.ids
          })
      else
        ProjektEvent.with_active_projekt
      end
  end

  def render?
    events.any?
  end

  private

    def events
      @events ||=
        @original_events
          .sort_by_incoming
          .first(@limit)
    end
end
