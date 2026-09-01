class ContentCard::ActiveProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @limit = @content_card.settings["limit"].to_i
    @custom_page = custom_page
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
        ContentCard::ProjektBuckets.for(@custom_page, current_user).active.first(@limit)
    end
end
