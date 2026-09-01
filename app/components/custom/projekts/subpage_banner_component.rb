class Projekts::SubpageBannerComponent < ApplicationComponent
  def initialize(title:, projekt:, date_range: nil)
    @title = title
    @projekt = projekt
    @date_range = date_range
    @custom_page = @projekt.page
  end

  def projekt_title
    @custom_page.title
  end

  def projekt_subtitle
    @custom_page.subtitle
  end

  def projekt_url
    page_path(@custom_page.slug)
  end

  def image_url
    return nil unless @custom_page.image.present?

    polymorphic_path(@custom_page.image.attachment_variant(
      coalesce: true,
      gravity: "center",
      resize_to_fill: [930, 585]
    ))
  end

  def has_image?
    @custom_page.image.present?
  end
end
