class ContentCard::ActiveProjektsComponent < ApplicationComponent
  delegate :current_user, to: :helpers

  def initialize(settings:)
    @limit = settings["limit"]
  end

  def render?
    active_projekts.any?
  end

  private

    def active_projekts
      @active_projekts = Projekt.show_in_homepage
        .index_order_underway
        .select { |p| p.visible_for?(current_user) }
        .first(@limit)
    end
end
