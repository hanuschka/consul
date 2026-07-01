# frozen_string_literal: true

class Ckeditor::AssetsController < ApplicationController
  def index
    authorize! :index, AdminAsset
    @assets = AdminAssetsQuery.new(params).call.page(params[:page]).per(15)

    respond_to do |format|
      format.html { render layout: false }
      format.json { render json: json }
    end
  end

  private

    def assets_json
      allowed_attributes = %i[
        id data_file_name data_content_type data_file_size width height title description alt_text
        url thumb_url
      ]

      @assets.map do |asset|
        asset.attributes.symbolize_keys.slice(*allowed_attributes).merge(
          url: asset.url_content(editor_id: params[:editor_id]),
          thumb_url: asset.custom_thumb_url(width: 232, height: 190),
          created_at: asset.created_at.strftime("%d.%m.%Y")
        )
      end
    end

    def json
      {
        items: assets_json,
        total_pages: @assets.total_pages,
        items_per_page: @assets.limit_value
      }
    end
end
