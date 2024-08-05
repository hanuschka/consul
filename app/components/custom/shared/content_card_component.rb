class Shared::ContentCardComponent < ApplicationComponent
  def initialize(content_card)
    @content_card = content_card
  end

  def render?
    @content_card.present?
  end

  private

    def render_content_card_component
      case @content_card.kind
      when "active_projekts"
        render ContentCard::ActiveProjektsComponent.new(@content_card)
      when "latest_user_activity"
        render ContentCard::LatestUserActivityComponent.new(@content_card)
      when "current_polls"
        render ContentCard::CurrentPollsComponent.new(@content_card)
      when "latest_resources"
        render ContentCard::LatestResourcesComponent.new(@content_card)
      when "expired_projekts"
        render ContentCard::ExpiredProjektsComponent.new(@content_card)
      when "events"
        render ContentCard::EventsComponent.new(@content_card)
      end
    end
end
