# frozen_string_literal: true

class BlobsController < ApplicationController
  skip_authorization_check only: :show

  def show
    blob = ActiveStorage::Blob.find_by!(key: params[:key])

    unless publicly_accessible?(blob)
      raise ActiveRecord::RecordNotFound
    end

    send_file(
      blob.service.send(:path_for, blob.key),
      type: blob.content_type,
      disposition: "inline"
    )
  end

  private

    def publicly_accessible?(blob)
      ActiveStorage::Attachment.exists?(blob_id: blob.id, record_type: allowed_record_types)
    end

    def allowed_record_types
      %w[Ckeditor::Asset Document]
    end
end
