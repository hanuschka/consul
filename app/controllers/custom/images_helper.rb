require_dependency Rails.root.join("app", "helpers", "images_helper").to_s

module ImagesHelper
 def render_image_attachment(builder, imageable, image)
    klass = image.persisted? || image.cached_attachment.present? ? " hide" : ""
    builder.file_field :attachment,
                       label_options: { class: "button hollow #{klass} js-access-label-to-button focusable", tabindex: "0", role: 'button' },
                       accept: imageable_accepted_content_types_extensions,
                       class: "js-image-attachment",
                       data: {
                         url: image_direct_upload_path(imageable),
                         nested_image: true
                       }
  end

  def render_attachment(builder, document)
    klass = document.persisted? || document.cached_attachment.present? ? " hide" : ""
    builder.file_field :attachment,
                       label_options: { class: "button hollow #{klass} js-access-label-to-button focusable", tabindex: "0", role: 'button' },
                       accept: accepted_content_types_extensions(document.documentable_type.constantize),
                       class: "js-document-attachment",
                       data: {
                         url: document_direct_upload_path(document),
                         nested_document: true
                       }
  end

  def show_image_thumbnail?(resource)
    resource.image.present? && !resource.image.concealed? && resource.image.attachment&.attached?
  end

  # Map popups are assembled in App.MapPopup, so the disclosure badge cannot be
  # rendered by Shared::AiImageLabelComponent there. The icon path and the
  # translated wording travel with the popup payload instead of being hardcoded
  # in the JS.
  def ai_image_label_payload(image)
    return nil if image.blank? || !image.ai_generated?

    {
      text: I18n.t(Shared::AiImageLabelComponent::TEXT_KEY),
      icon_url: asset_path("ai_disclosure/eu_ai_generated_icon.svg")
    }
  end
end
