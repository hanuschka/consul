class Shared::ContentCardComponent < ApplicationComponent
  def initialize(content_card, custom_page: nil)
    @content_card = content_card
    @custom_page = custom_page
  end

  def render?
    @content_card.present?
  end

  private

    def render_content_card_component
      case @content_card.kind
      when "active_projekts"
        render ContentCard::ActiveProjektsComponent.new(@content_card, custom_page: @custom_page)
      when "current_projekts"
        render ContentCard::CurrentProjektsComponent.new(@content_card, custom_page: @custom_page)
      when "latest_user_activity"
        render ContentCard::LatestUserActivityComponent.new(@content_card, custom_page: @custom_page)
      when "current_polls"
        render ContentCard::CurrentPollsComponent.new(@content_card, custom_page: @custom_page)
      when "latest_resources"
        render ContentCard::LatestResourcesComponent.new(@content_card, custom_page: @custom_page)
      when "expired_projekts"
        render ContentCard::ExpiredProjektsComponent.new(@content_card, custom_page: @custom_page)
      when "events"
        render ContentCard::EventsComponent.new(@content_card, custom_page: @custom_page)
      end
    end
end
