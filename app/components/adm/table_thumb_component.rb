class Adm::TableThumbComponent < ApplicationComponent
  def initialize(image:, title:, fallback_icon: nil, fallback_color: nil)
    @image = image
    @title = title
    @fallback_icon = fallback_icon
    @fallback_color = fallback_color
  end

  private

    attr_reader :image, :title, :fallback_icon, :fallback_color

    def image_attached?
      image&.attachment&.attached?
    end

    def fallback_icon?
      fallback_icon.present?
    end

    def category_style
      [
        ("background: color-mix(in srgb, #{fallback_color} 18%, transparent)" if fallback_color.present?),
        ("color: #{fallback_color}" if fallback_color.present?)
      ].compact.join("; ")
    end
end
