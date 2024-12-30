class Ckeditor::Picture < ApplicationRecord
  include Rails.application.routes.url_helpers

  self.table_name = "ckeditor_assets"

  EDITORS_WITH_FULL_URL = %w[newsletter_body].freeze
  ALLOWED_CONTENT_TYPES = %w[image/jpg image/jpeg image/png image/gif].freeze
  MAX_FILE_SIZE = Setting["uploads.images.max_size"].to_i.megabytes

  has_one_attached :storage_data

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

  def url_thumb
    if data_content_type == "image/gif"
      rails_blob_url(storage_data, only_path: true)
    else
      rails_representation_url(
        storage_data.variant(coalesce: true, resize: "118x100", loader: { page: nil }), only_path: true
      )
    end
  end

  def attach_uploaded_file(data)
    return unless data.is_a?(ActionDispatch::Http::UploadedFile)

    storage_data.attach(io: data, filename: data.original_filename, content_type: data.content_type)

    self.data_file_name = data.original_filename
    self.data_content_type = data.content_type
    self.data_file_size = data.size
    self.type = "Ckeditor::Picture"
  end

  private

    def absolute_path?(editor_id)
      editor_id.present? && EDITORS_WITH_FULL_URL.include?(editor_id)
    end
end
