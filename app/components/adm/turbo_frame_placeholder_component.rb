class Adm::TurboFramePlaceholderComponent < ApplicationComponent
  def initialize(text: nil, min_height: nil, icon: "progress_activity")
    @text = text
    @min_height = min_height
    @icon = icon
  end

  def text
    @text.presence || t(".loading")
  end

  def icon
    @icon
  end

  def container_style
    return nil if @min_height.blank?

    "min-height: #{@min_height.to_i}px;"
  end
end
