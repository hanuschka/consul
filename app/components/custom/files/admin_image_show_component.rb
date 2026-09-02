class Files::AdminImageShowComponent < Files::AssetShowComponent
  def filename
    admin_image.data_file_name.presence || admin_image.title.presence || I18n.t("files.show.untitled")
  end

  def has_attachment?
    admin_image.storage_data.attached?
  end

  def humanized_size
    return "" if admin_image.data_file_size.blank?

    helpers.number_to_human_size(admin_image.data_file_size)
  end

  def content_type
    admin_image.data_content_type.to_s
  end

  def dimensions
    return nil if admin_image.width.blank?
    return nil if admin_image.height.blank?

    "#{admin_image.width} × #{admin_image.height}"
  end

  def image_display_url
    return nil if !has_attachment?

    admin_image.url_content
  end

  def attachment_url
    image_display_url
  end

  private

    def admin_image
      record
    end

    def attached_resource
      nil
    end
end
