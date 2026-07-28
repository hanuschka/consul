class ContentCard::ExpiredProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
    @projekts =
      if custom_page.present?
        custom_page.landing_projekts.show_in_homepage
      else
        Projekt.show_in_homepage
      end
  end

  def render?
    expired_projekts.any?
  end

  private

    def expired_projekts
      @expired_projekts ||=
        @projekts
          .visible_for(current_user)
          .includes(
            :projekt_settings, :tags,
            page: [:image, :translations],
            active_and_visible_projekt_phases: [:translations, :settings]
          )
          .preload(sdg_relations: :related_sdg)
          .index_order_expired
          .sort_by_order_number
          .first(@limit)
    end
end
