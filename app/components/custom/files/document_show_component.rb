class Files::DocumentShowComponent < Files::AssetShowComponent
  def filename
    attachment_filename.presence || document.title.presence || I18n.t("files.show.untitled")
  end

  def has_attachment?
    document.attachment.attached?
  end

  def humanized_size
    return "" if !has_attachment?

    helpers.number_to_human_size(document.attachment.byte_size)
  end

  def content_type
    return "" if !has_attachment?

    document.attachment.content_type.to_s
  end

  def previewable?
    return false if !has_attachment?

    document.attachment.blob.previewable?
  end

  def preview_image_url
    return nil if !previewable?

    helpers.rails_representation_url(
      document.attachment.blob.preview(resize_to_limit: [1000, 1400]),
      only_path: true
    )
  end

  def attachment_url
    return nil if !has_attachment?

    helpers.rails_blob_url(document.attachment, **UrlOptions.default)
  end

  def admin_upload?
    document.admin?
  end

  private

    def document
      record
    end

    def attachment_filename
      return "" if !document.attachment.attached?

      document.attachment.filename.to_s
    end

    def attached_resource
      document.documentable
    end
end
