module Adm::ProjektsHelper
  def projekt_thumbnail(projekt)
    if projekt.image&.attached?
      image_tag(projekt.image.variant(:thumb2),
                class: "thumbnail thumbnail--image",
                alt: projekt.page&.title)
    elsif projekt.images.attached?
      image_tag(url_for(projekt.images.blobs.first.variant(resize_to_fill: [48, 48])),
                class: "thumbnail thumbnail--image",
                alt: projekt.page&.title)
    else
      content_tag(:div, class: "thumbnail") do
        content_tag(:span, "folder", class: "material-symbols-outlined", "aria-hidden": "true")
      end
    end
  rescue StandardError
    content_tag(:div, class: "thumbnail") do
      content_tag(:span, "folder", class: "material-symbols-outlined", "aria-hidden": "true")
    end
  end

  # A city that repeats a procedure every year runs it under the same name every
  # time, and copying a projekt keeps the name as well, so the bare name leaves
  # an admin picking between identical rows. The years the projekt ran are what
  # tells the rounds apart, and they read the same in every locale.
  def similar_search_projekt_label(projekt)
    years = similar_search_projekt_years(projekt)

    return projekt.name if years.blank?

    "#{projekt.name} (#{years})"
  end

  private

    def similar_search_projekt_years(projekt)
      start_year = projekt.total_duration_start&.year
      end_year = projekt.total_duration_end&.year

      return if start_year.blank? && end_year.blank?
      return start_year.to_s if start_year == end_year

      "#{start_year}–#{end_year}"
    end
end
