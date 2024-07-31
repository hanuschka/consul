class ContentCard::LatestUserActivityComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(settings:)
    @settings = settings
  end

  def render?
    true
  end
end
