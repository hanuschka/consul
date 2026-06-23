class Files::DocumentCardComponent < Files::ResourceAssetComponent
  with_collection_parameter :document

  def initialize(document:, type:)
    @document = document
    @type = type
  end

  private

    attr_reader :document, :type

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

    def documentable_name
      resource_name(document.documentable)
    end

    def documentable_url
      resource_url(document.documentable)
    end

    def admin_upload?
      document.admin?
    end

    def icon_class
      FileTypeIcons.for(attachment_content_type)
    end

    def filetype_label
      extension = File.extname(filename).delete(".").upcase

      return I18n.t("files.card.file_type", type: extension) if extension.present?

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
