class ContentCard::EventsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
    @limit = @content_card.settings['limit'].to_i
  end

  def render?
    events.any?
  end

  private

    def events
      @events ||= ProjektEvent.with_active_projekt.sort_by_incoming.first(@limit)
    end
end
