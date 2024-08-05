class ContentCard::EventsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
  end

  def render?
    events.any?
  end

  private

    def events
      @events ||= ProjektEvent.sort_by_incoming
    end
end
