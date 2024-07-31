class Shared::ContentCardComponent < ApplicationComponent
  def initialize(content_card)
    @content_card = content_card
  end

  def render?
    @content_card.present?
  end

  private

    def render_content_card_component(kind:, settings:)
      case kind
      when "active_projekts"
        render ContentCard::ActiveProjektsComponent.new(settings: settings)
      when "latest_user_activity"
        render ContentCard::LatestUserActivityComponent.new(settings: settings)
      when "current_polls"
        render ContentCard::CurrentPollsComponent.new(settings: settings)
      when "latest_resources"
        render ContentCard::LatestResourcesComponent.new(settings: settings)
      when "expired_projekts"
        render ContentCard::ExpiredProjektsComponent.new(settings: settings)
      when "events"
        render ContentCard::EventsComponent.new(settings: settings)
      end
    end

    def render_content_card
      settings = @content_card.settings
      kind = @content_card.kind

      render_content_card_component(kind: kind, settings: settings)
    end
end
