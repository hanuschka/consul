class ContentCard::CurrentPollsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(settings:)
    @settings = settings
  end

  def render?
    current_polls.any?
  end

  private

    def current_polls
      @current_polls ||= Poll.current.where(show_on_home_page: true).order(created_at: :asc)
    end
end
