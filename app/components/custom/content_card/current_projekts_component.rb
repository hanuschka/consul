class ContentCard::CurrentProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
    @projekts =
      if custom_page.present?
        custom_page.landing_projekts
      else
        Projekt.show_in_homepage
      end
  end

  def render?
    current_projekts.any?
  end

  private

    def current_projekts
      @current_projekts =
        @projekts
          .sort_by_order_number
          .index_order_underway
          .select { |p| p.visible_for?(current_user) }
          .first(@limit)
    end
end
