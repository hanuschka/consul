class Files::DocumentRowComponent < Files::ResourceAssetComponent
  TITLE_TRUNCATE_LENGTH = 50

  with_collection_parameter :document

  def initialize(document:)
    @document = document
  end

  private

    attr_reader :document

    def title_truncated?
      display_title.length > TITLE_TRUNCATE_LENGTH
    end

    def truncated_title
      display_title.truncate(TITLE_TRUNCATE_LENGTH)
    end

    def title_popover_id
      "files-document-title-popover-#{document.id}"
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

    def attachment_url
      return "" if !document.attachment.attached?

      helpers.url_for(document.attachment)
    end

    def update_url
      helpers.adm_files_document_path(document)
    end
end
