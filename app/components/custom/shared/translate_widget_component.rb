class Shared::TranslateWidgetComponent < ApplicationComponent
  delegate :google_translate_accepted?, to: :helpers

  def initialize(placement)
    @placement = placement
  end

  def render?
    extended_feature?("general.enable_google_translate")
  end
end
