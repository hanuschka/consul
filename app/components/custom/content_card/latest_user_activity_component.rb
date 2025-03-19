class ContentCard::LatestUserActivityComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @custom_page = custom_page
  end

  def render?
    true
  end
end
