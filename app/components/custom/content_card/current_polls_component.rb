class ContentCard::CurrentPollsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
  end

  def render?
    current_polls.any?
  end

  private

    def current_polls
      @current_polls ||= Poll.current
        .with_phase_feature("resource.show_on_home_page")
        .order(created_at: :asc)
    end
end
