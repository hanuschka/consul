class ContentCard::ExpiredProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
  end

  def render?
    expired_projekts.any?
  end

  private

    def expired_projekts
      @expired_projekts = Projekt.show_in_homepage
        .sort_by_order_number
        .index_order_expired
        .select { |p| p.visible_for?(current_user) }
        .first(@limit)
    end
end
