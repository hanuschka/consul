class Ckeditor::Document < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[application/pdf].freeze
  MAX_FILE_SIZE = Setting["uploads.images.max_size"].to_i.megabytes

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def url_content(editor_id: nil)
    absolute_path?(editor_id) ? rails_blob_url(storage_data, host: Setting["url"]) : rails_blob_path(storage_data, only_path: true)
  end

  def url_thumb(editor_id: nil)
    ""
  end

  def type
    "Ckeditor::Document"
  end
end
