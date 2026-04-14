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
end
