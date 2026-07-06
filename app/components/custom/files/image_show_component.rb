class Files::ImageShowComponent < Files::AssetShowComponent
  def filename
    attachment_filename.presence || image.title.presence || I18n.t("files.show.untitled")
  end

  def has_attachment?
    image.attachment.attached?
  end

  def humanized_size
    return "" if !has_attachment?

    helpers.number_to_human_size(image.attachment.byte_size)
  end

  def content_type
    return "" if !has_attachment?

    image.attachment.content_type.to_s
  end

  def dimensions
    meta = attachment_metadata
    width = meta[:width] || meta["width"]
    height = meta[:height] || meta["height"]
    return nil if width.blank? || height.blank?

    "#{width} × #{height}"
  end

  def image_display_url
    return nil if !has_attachment?

    helpers.url_for(image.attachment)
  end

  def attachment_url
    image_display_url
  end

  def admin_upload?
    image.admin?
  end

  private

    def image
      record
    end

    def attachment_filename
      return "" if !image.attachment.attached?

      image.attachment.filename.to_s
    end

    def attachment_metadata
      return {} if !image.attachment.attached?

      image.attachment.metadata || {}
    end

    def attached_resource
      image.imageable
    end
end
