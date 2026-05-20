class Ckeditor::Picture < Ckeditor::Asset
  ALLOWED_CONTENT_TYPES = %w[image/jpg image/jpeg image/png image/gif image/webp image/avif].freeze
  MAX_FILE_SIZE = 10.megabytes

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def url_content(editor_id: nil)
    if data_content_type == "image/gif"
      blob_asset_path(storage_data.blob.key)
    elsif absolute_path?(editor_id)
      blob_variant_url(storage_data.blob.key, host: Setting["url"], w: 1500, h: 2000)
    else
      blob_variant_path(storage_data.blob.key, w: 1500, h: 2000)
    end
  end

  def url_thumb(editor_id: nil)
    if data_content_type == "image/gif"
      rails_blob_url(storage_data, only_path: true)
    else
      rails_representation_url(
        storage_data.variant(resize_to_fill: [190, 190]), only_path: true
      )
    end
  end

  def custom_thumb_url(width: nil, height: nil, pad: 0)
    if data_content_type == "image/gif"
      rails_blob_url(storage_data, only_path: true)
    else
      if width.present?
        width = width + pad
      end

      if height.present?
        height = height + pad
      end

      rails_representation_url(
        storage_data.variant(
          resize_to_fit: [width, height],
          saver: { quality: 88 }
        ),
        only_path: true
      )
    end
  end

  def gallery_thumb_url
    # custom_thumb_url(
    #   width: 205,
    #   height: 180
    # )
    rails_representation_url(
      storage_data.variant(
        resize_to_fill: [210, nil],
        saver: { quality: 90 }
      ),
      only_path: true
    )
  end

  def type
    "Ckeditor::Picture"
  end
end
