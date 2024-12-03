class Ckeditor::Document < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[application/pdf].freeze

  def url_content(editor_id: nil)
    absolute_path?(editor_id) ? rails_blob_url(storage_data, host: Setting["url"]) : rails_blob_path(storage_data, only_path: true)
  end

  def url_thumb
    ""
  end

  def type
    "Ckeditor::Document"
  end
end
