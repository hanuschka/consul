class ContentCard::CurrentPollsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = content_card.settings['limit'].to_i
    @custom_page = custom_page

    @original_polls =
      if @custom_page.present?
        Poll
          .joins(:projekt_phase)
          .where(projekt_phases: {
            active: true,
            projekt_id: @custom_page.landing_projekts.ids
          })
      else
        Poll
      end
  end

  def render?
    current_polls.any?
  end

  private

    def current_polls
      @current_polls ||=
        @original_polls
          .current
          .with_phase_feature("resource.show_on_home_page")
          .order(created_at: :asc)
    end
end
