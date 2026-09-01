class Shared::AiFeatureTooltipComponent < ApplicationComponent
  def initialize(feature_text:, feature_title: nil, placement: "top", layout_class: nil, requires_ai: true)
    @feature_text = feature_text
    @feature_title = feature_title
    @placement = placement
    @layout_class = layout_class
    @requires_ai = requires_ai
  end

  def ai_disabled?
    requires_ai && !Ai::Settings.ai_available?
  end

  private

  attr_reader :feature_text, :feature_title, :placement, :layout_class, :requires_ai
end
