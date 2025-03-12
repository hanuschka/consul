class ContentCard::ActiveProjektsComponent < ApplicationComponent
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
    active_projekts.any?
  end

  private

    def active_projekts
      @active_projekts =
        @projekts
          .sort_by_order_number
          .activated
          .where.not(id: excluded_projekts_ids)
          .select { |p| p.visible_for?(current_user) }
          .first(@limit)
    end

    def excluded_projekts_ids
      current_projekts_ids = @projekts.index_order_underway.map(&:id)
      expired_projekts_ids = @projekts.index_order_expired.map(&:id)

      [current_projekts_ids + expired_projekts_ids].flatten.uniq
    end
end
