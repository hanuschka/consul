class ContentCard::LatestUserActivityComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
  end

  def render?
    true
  end
end
