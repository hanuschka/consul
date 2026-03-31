module Adm::ProjektsHelper
  def projekt_thumbnail(projekt)
    first_image = projekt.images.blobs.first if projekt.images.attached?

    if first_image.present?
      image_tag(url_for(first_image.variant(resize_to_fill: [48, 48])),
                class: "thumbnail thumbnail--image",
                alt: projekt.page.title)
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
