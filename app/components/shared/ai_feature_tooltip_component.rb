class Shared::AiFeatureTooltipComponent < ApplicationComponent
  def initialize(feature_text:, feature_title: nil, placement: "top", trigger_class: nil)
    @feature_text = feature_text
    @feature_title = feature_title
    @placement = placement
    @trigger_class = trigger_class
  end

  def ai_disabled?
    !Ai::Settings.ai_available?
  end

  private

  attr_reader :feature_text, :feature_title, :placement, :trigger_class
end
