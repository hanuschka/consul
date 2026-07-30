class ContentCard::ExpiredProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
    @custom_page = custom_page
  end

  def render?
    expired_projekts.any?
  end

  private

    def expired_projekts
      @expired_projekts ||=
        ContentCard::ProjektBuckets.for(@custom_page, current_user).expired.first(@limit)
    end
end
