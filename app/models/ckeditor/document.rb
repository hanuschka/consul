class Ckeditor::Document < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[application/pdf].freeze
  MAX_FILE_SIZE = Setting["uploads.images.max_size"].to_i.megabytes

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def url_content(editor_id: nil)
    blob = storage_data.blob
    return "" unless blob

    absolute_path?(editor_id) ? ckeditor_asset_url(blob.key, host: Setting["url"]) : ckeditor_asset_path(blob.key, only_path: true)
  end

  def url_thumb(editor_id: nil)
    ""
  end

  def custom_thumb_url(width: 890, height: 890)
    ""
  end

  def gallery_thumb_url
    ""
  end

  def type
    "Ckeditor::Document"
  end
end
