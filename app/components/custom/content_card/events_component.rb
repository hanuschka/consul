class ContentCard::EventsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(settings:)
    @settings = settings
  end

  def render?
    events.any?
  end

  private

    def events
      @events ||= ProjektEvent.sort_by_incoming
    end
end
