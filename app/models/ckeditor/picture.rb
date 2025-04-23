class Ckeditor::Picture < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[image/jpg image/jpeg image/png image/gif].freeze
  MAX_FILE_SIZE = Setting["uploads.images.max_size"].to_i.megabytes

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def url_content(editor_id: nil)
    file_path = if data_content_type == "image/gif"
                  rails_blob_url(storage_data, only_path: true)
                else
                  rails_representation_url(
                    storage_data.variant(coalesce: true, resize: "800>", loader: { page: nil }), only_path: true
                  )
                end

    absolute_path?(editor_id) ? Setting["url"] + file_path : file_path
  end

  def url_thumb(editor_id: nil)
    if data_content_type == "image/gif"
      rails_blob_url(storage_data, only_path: true)
    else
      rails_representation_url(
        storage_data.variant(coalesce: true, gravity: "center", resize: "190x190^", crop: "190x190+0+0", loader: { page: nil }), only_path: true
      )
    end
  end

  def type
    "Ckeditor::Picture"
  end
end
