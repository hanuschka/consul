class ProjektPhaseStatsHeaderComponent < ApplicationComponent
  delegate :format_date_range, to: :helpers

  def initialize(projekt_phase:)
    @projekt_phase = projekt_phase
    @projekt = projekt_phase.projekt
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

  def phase_title
    @projekt_phase.title
  end

  def phase_date_range
    return nil if @projekt_phase.start_date.blank? && @projekt_phase.end_date.blank?

    format_date_range(@projekt_phase.start_date, @projekt_phase.end_date)
  end

  def image_url
    return nil unless @custom_page.image.present?

    polymorphic_path(@custom_page.image.attachment.variant(
      coalesce: true,
      gravity: "center",
      resize_to_fill: [930, 585]
    ))
  end

  def has_image?
    @custom_page.image.present?
  end
end
