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

  # Map popups and the studio banner assemble their HTML in JavaScript, so the
  # badge is rendered here and travels as markup. Keeping the component as the
  # only definition means the wording, the icon and the class names cannot drift
  # between the server-rendered surfaces and the scripted ones.
  def ai_image_label_html(image)
    return nil if image.blank? || !image.ai_generated?

    render(Shared::AiImageLabelComponent.new)
  end
end
