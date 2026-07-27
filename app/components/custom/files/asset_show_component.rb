class Files::AssetShowComponent < Files::ResourceAssetComponent
  def initialize(record:)
    @record = record
  end

  def display_title
    record.title.presence || filename
  end

  def uploaded_by
    record.user
  end

  def created_at_long
    I18n.l(record.created_at, format: :long)
  end

  def updated_at_long
    I18n.l(record.updated_at, format: :long)
  end

  def resource_type_label
    return nil if attached_resource.blank?

    attached_resource.model_name.human
  end

  def owning_resource_label
    owning_resource_type_label(attached_resource)
  end

  def owning_resource_name
    resource_name(owning_resource(attached_resource))
  end

  def owning_resource_url
    resource_url(owning_resource(attached_resource))
  end

  def projekt_name
    resource_name(resource_projekt(attached_resource))
  end

  def projekt_url
    resource_url(resource_projekt(attached_resource))
  end

  def file_extension
    File.extname(filename).delete(".").upcase.presence
  end

  def filetype_label
    return I18n.t("files.card.file_type", type: file_extension) if file_extension.present?

    I18n.t("files.card.file_type_generic")
  end

  def icon_class
    FileTypeIcons.for(content_type)
  end

  def filename
    I18n.t("files.show.untitled")
  end

  def has_attachment?
    false
  end

  def humanized_size
    ""
  end

  def content_type
    ""
  end

  def dimensions
    nil
  end

  def image_display_url
    nil
  end

  def preview_image_url
    nil
  end

  def attachment_url
    nil
  end

  def admin_upload?
    false
  end

  private

    attr_reader :record

    def attached_resource
      nil
    end
end
