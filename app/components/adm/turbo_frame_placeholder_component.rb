class Adm::TurboFramePlaceholderComponent < ApplicationComponent
  def initialize(text: nil, min_height: nil, icon: "progress_activity", logo_path: nil, logo_alt: "")
    @text = text
    @min_height = min_height
    @icon = icon
    @logo_path = logo_path
    @logo_alt = logo_alt
  end

  def text
    @text.presence || t(".loading")
  end

  def icon
    @icon
  end

  def logo_path
    @logo_path
  end

  def logo_alt
    @logo_alt.to_s
  end

  def container_style
    return nil if @min_height.blank?

    "min-height: #{@min_height.to_i}px;"
  end
end
