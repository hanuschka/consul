class AdminDocument < AdminAsset
  ALLOWED_CONTENT_TYPES = %w[
    application/pdf
    application/msword
    application/vnd.openxmlformats-officedocument.wordprocessingml.document
    application/vnd.ms-excel
    application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
    application/vnd.ms-powerpoint
    application/vnd.openxmlformats-officedocument.presentationml.presentation
    application/vnd.oasis.opendocument.text
    application/vnd.oasis.opendocument.spreadsheet
    text/plain
    text/csv
    application/rtf
    text/rtf
  ].freeze
  MAX_FILE_SIZE = 10.megabytes

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def url_content(editor_id: nil)
    blob = storage_data.blob
    return "" unless blob

    absolute_path?(editor_id) ? blob_asset_url(blob.key, host: Setting["url"]) : blob_asset_path(blob.key, only_path: true)
  end

  def url_thumb(editor_id: nil)
    ""
  end

  def custom_thumb_url(width: 890, height: 890)
    blob = storage_data.blob
    return "" unless blob&.previewable?

    rails_representation_url(
      blob.preview(resize_to_limit: [width, height]),
      only_path: true
    )
  end

  def gallery_thumb_url
    blob = storage_data.blob
    return "" unless blob&.previewable?

    rails_representation_url(
      blob.preview(resize_to_limit: [464, 380]),
      only_path: true
    )
  end
end
