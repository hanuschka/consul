class AdminImage < ApplicationRecord
  include AdminUploadable

  belongs_to :user, optional: true

  ALLOWED_CONTENT_TYPES = %w[image/jpg image/jpeg image/png image/gif image/webp image/avif].freeze
  UNPROCESSED_CONTENT_TYPES = %w[image/gif].freeze
  MAX_FILE_SIZE = 10.megabytes

  CONTENT_BLOCK_THUMB_WIDTH = 1200
  CONTENT_BLOCK_THUMB_HEIGHT = 1000

  validates :storage_data, file_content_type: { allow: ALLOWED_CONTENT_TYPES },
                           file_size: { less_than: MAX_FILE_SIZE }

  def self.humanized_allowed_content_types
    Setting.humanized_content_types_for("images", ALLOWED_CONTENT_TYPES)
           .split(", ").uniq.join(", ")
  end

  def attach_processed_upload(upload, max_width: 3000, max_height: 2000)
    return unless upload.is_a?(ActionDispatch::Http::UploadedFile)

    unless processable_content_type?(upload.content_type)
      return attach_uploaded_file(upload)
    end

    processed_image = ImageProcessing::MiniMagick
      .source(upload)
      .convert("jpg")
      .resize_to_fit(max_width, max_height)
      .saver(quality: 87, interlace: "Line")
      .call

    attach_uploaded_file(upload, processed_image)
  end

  def url_content(editor_id: nil)
    if unprocessed_content_type?
      blob_asset_path(storage_data.blob.key)
    elsif absolute_path?(editor_id)
      blob_variant_url(storage_data.blob.key, host: Setting["url"], w: 1500, h: 2000)
    else
      blob_variant_path(storage_data.blob.key, w: 1500, h: 2000)
    end
  end

  def url_thumb(editor_id: nil)
    if unprocessed_content_type?
      rails_blob_url(storage_data, only_path: true)
    else
      rails_representation_url(
        storage_data.variant(resize_to_fill: [190, 190]), only_path: true
      )
    end
  end

  def custom_thumb_url(width: nil, height: nil, pad: 0)
    if unprocessed_content_type?
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

  def content_block_thumb_url
    if unprocessed_content_type?
      blob_asset_path(storage_data.blob.key)
    else
      blob_variant_path(
        storage_data.blob.key,
        w: CONTENT_BLOCK_THUMB_WIDTH,
        h: CONTENT_BLOCK_THUMB_HEIGHT
      )
    end
  end

  def gallery_thumb_url
    # custom_thumb_url(
    #   width: 205,
    #   height: 180
    # )
    return rails_blob_url(storage_data, only_path: true) if unprocessed_content_type?

    rails_representation_url(
      storage_data.variant(
        resize_to_fill: [210, nil],
        saver: { quality: 90 }
      ),
      only_path: true
    )
  end

  private

    def unprocessed_content_type?
      UNPROCESSED_CONTENT_TYPES.include?(data_content_type)
    end

    def processable_content_type?(content_type)
      ALLOWED_CONTENT_TYPES.include?(content_type) &&
        !UNPROCESSED_CONTENT_TYPES.include?(content_type)
    end
end
