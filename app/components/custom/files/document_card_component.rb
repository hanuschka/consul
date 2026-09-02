class Files::DocumentCardComponent < Files::ResourceAssetComponent
  with_collection_parameter :document

  def initialize(document:, type:, detail_path: nil)
    @document = document
    @type = type
    @detail_path = detail_path
  end

  private

    attr_reader :document, :type, :detail_path

    def detail_url
      return nil if detail_path.blank?

      detail_path.call(document)
    end

    def owning_resource_label
      owning_resource_type_label(document.documentable)
    end

    def owning_resource_name
      resource_name(owning_resource(document.documentable))
    end

    def owning_resource_url
      resource_url(owning_resource(document.documentable))
    end

    def projekt_name
      resource_name(resource_projekt(document.documentable))
    end

    def projekt_url
      resource_url(resource_projekt(document.documentable))
    end

    def uploaded_by
      document.user
    end

    def filename
      attachment_filename.presence || document.title.presence || "Untitled"
    end

    def display_title
      document.title.presence || filename
    end

    def attachment_filename
      return "" if !document.attachment.attached?

      document.attachment.filename.to_s
    end

    def attachment_byte_size
      return nil if !document.attachment.attached?

      document.attachment.byte_size
    end

    def attachment_content_type
      return "" if !document.attachment.attached?

      document.attachment.content_type.to_s
    end

    def humanized_size
      bytes = attachment_byte_size
      return "" if bytes.blank?

      helpers.number_to_human_size(bytes)
    end

    def created_at_formatted
      I18n.l(document.created_at, format: :short)
    end

    def updated_at_formatted
      I18n.l(document.updated_at, format: :short)
    end

    def documentable_type_label
      type_string = document.documentable_type.to_s
      type_string.safe_constantize&.model_name&.human || type_string
    end

    def admin_upload?
      document.admin?
    end

    def icon_class
      FileTypeIcons.for(attachment_content_type)
    end

    def file_extension
      File.extname(filename).delete(".").upcase.presence
    end

    def filetype_label
      return I18n.t("files.card.file_type", type: file_extension) if file_extension.present?

      I18n.t("files.card.file_type_generic")
    end

    def attachment_url
      return "" if !document.attachment.attached?

      helpers.rails_blob_url(document.attachment, **UrlOptions.default)
    end

    def previewable?
      return false if !document.attachment.attached?

      document.attachment.blob.previewable?
    end

    def preview_url
      helpers.rails_representation_url(
        document.attachment.blob.preview(resize_to_limit: [600, 450]),
        only_path: true
      )
    end

    def update_url
      helpers.adm_files_document_path(document)
    end
end
