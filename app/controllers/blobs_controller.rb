# frozen_string_literal: true

class BlobsController < ApplicationController
  skip_authorization_check only: [:show, :variant]

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

  ALLOWED_VARIANT_SIZES = [
    [1500, 2000],
    [AdminImage::CONTENT_BLOCK_THUMB_WIDTH, AdminImage::CONTENT_BLOCK_THUMB_HEIGHT]
  ].freeze

  def variant
    blob = ActiveStorage::Blob.find_by!(key: params[:key])

    unless publicly_accessible?(blob) && blob.variable?
      raise ActiveRecord::RecordNotFound
    end

    width = (params[:w] || 1500).to_i
    height = (params[:h] || 2000).to_i

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
