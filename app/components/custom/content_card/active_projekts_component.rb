class ContentCard::ActiveProjektsComponent < ApplicationComponent
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
    active_projekts.any?
  end

  private

    def projekts_path(**kwargs)
      if @custom_page.present? && @custom_page.landing?
        landing_page_projekts_path(@custom_page.slug, **kwargs)
      else
        helpers.projekts_path(**kwargs)
      end
    end

    def active_projekts
      @active_projekts ||=
        @projekts
          .activated
          .visible_for(current_user)
          .where.not(id: excluded_projekts_ids)
          .includes(
            :projekt_settings, :tags,
            page: [:image, :translations],
            active_and_visible_projekt_phases: [:translations, :settings]
          )
          .preload(sdg_relations: :related_sdg)
          .sort_by_order_number
          .first(@limit)
    end

    def excluded_projekts_ids
      @excluded_projekts_ids ||= begin
        current_projekts_ids = @projekts.index_order_underway.pluck(:id)
        expired_projekts_ids = @projekts.index_order_expired.pluck(:id)

        [current_projekts_ids + expired_projekts_ids].flatten.uniq
      end
    end
end
