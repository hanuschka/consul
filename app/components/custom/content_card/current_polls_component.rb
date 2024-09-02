class ContentCard::CurrentPollsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
    @limit = content_card.settings['limit'].to_i
  end

  def render?
    current_polls.any?
  end

  private

    def current_polls
<<<<<<< HEAD
      @current_polls ||= Poll.current.where(show_on_home_page: true).order(created_at: :asc).first(@limit)
=======
      @current_polls ||= Poll.current
        .with_phase_feature("resource.show_on_home_page")
        .order(created_at: :asc)
>>>>>>> cecd52d411d1d64280c0fd7823a64b784d8684d2
    end
end
