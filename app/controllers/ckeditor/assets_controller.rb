# frozen_string_literal: true

class Ckeditor::AssetsController < ApplicationController
  include Search
  skip_forgery_protection
  skip_authorization_check

  def index
    # authorize! :index, Ckeditor::Asset
    @assets = Ckeditor::Asset.joins(:storage_data_attachment)
    filter_by_type

    @assets = if @search_terms.present?
                @assets.search(@search_terms)
              else
                @assets.order(id: :desc)
              end

    @assets = @assets.page(params[:page]).per(10)

    render json: json
  end

  private

    def filter_by_type
      return unless params[:type].present?

      type = params[:type] == "document" ? "Ckeditor::Document" : "Ckeditor::Picture"
      @assets = @assets.where(type: type)
    end

    def assets_json
      allowed_attributes = %i[
        id data_file_name data_content_type data_file_size width height created_at title description alt_text
        url thumb_url
      ]

      @assets.map do |asset|
        asset.attributes.merge(
          url: asset.url_content(editor_id: params[:editor_id]),
          thumb_url: asset.url_thumb
        )
      end.to_json(only: allowed_attributes)
    end

    def json
      {
        items: assets_json,
        total_pages: @assets.total_pages,
        items_per_page: @assets.limit_value,
        page: @assets.current_page
      }
    end
end
