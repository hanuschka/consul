class ContentCard::CurrentProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
    @custom_page = custom_page
    @projekts =
      if custom_page.present?
        custom_page.landing_projekts.show_in_homepage
      else
        Projekt.show_in_homepage
      end
  end

  def render?
    current_projekts.any?
  end

  private

    def projekts_path(**kwargs)
      if @custom_page.present? && @custom_page.landing?
        landing_page_projekts_path(@custom_page.slug, **kwargs)
      else
        helpers.projekts_path(**kwargs)
      end
    end

    def current_projekts
      @current_projekts ||=
        @projekts
          .visible_for(current_user)
          .includes(
            :projekt_settings, :tags,
            page: [:image, :translations],
            active_and_visible_projekt_phases: [:translations, :settings]
          )
          .preload(sdg_relations: :related_sdg)
          .sort_by_order_number
          .index_order_underway
          .first(@limit)
    end
end
