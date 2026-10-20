# frozen_string_literal: true

class BlobsController < ActionController::Base
  def show
    blob = ActiveStorage::Blob.find_by!(key: params[:key])

    unless publicly_accessible?(blob)
      raise ActiveRecord::RecordNotFound
    end

    expires_in 1.year, public: true
    send_file(
      blob.service.send(:path_for, blob.key),
      type: blob.content_type,
      disposition: "inline"
    )
  end

  LEGACY_VARIANT_SIZES = [[925, 2000]].freeze

  ALLOWED_VARIANT_SIZES = ([
    [1500, 2000],
    [AdminImage::CONTENT_BLOCK_THUMB_WIDTH, AdminImage::CONTENT_BLOCK_THUMB_HEIGHT]
  ] + LEGACY_VARIANT_SIZES).uniq.freeze

  def variant
    blob = ActiveStorage::Blob.find_by!(key: params[:key])

    unless publicly_accessible?(blob) && blob.variable?
      raise ActiveRecord::RecordNotFound
    end

    width = Integer(params[:w].presence || 1500, exception: false)
    height = Integer(params[:h].presence || 2000, exception: false)

    unless ALLOWED_VARIANT_SIZES.include?([width, height])
      raise ActiveRecord::RecordNotFound
    end

    variation = blob.variant(resize_to_limit: [width, height])
    variation.processed

    expires_in 1.year, public: true
    send_file(
      blob.service.send(:path_for, variation.key),
      type: blob.content_type,
      disposition: "inline"
    )
  end

  private

    def publicly_accessible?(blob)
      ActiveStorage::Attachment.exists?(blob_id: blob.id, record_type: allowed_record_types)
    end

    def allowed_record_types
      %w[AdminAsset AdminImage Document Image]
    end
end
