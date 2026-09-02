class Files::AssetCardComponent < Files::ResourceAssetComponent
  with_collection_parameter :asset

  def initialize(asset:, type:, detail_path: nil)
    @asset = asset
    @type = type
    @detail_path = detail_path
  end

  private

    attr_reader :asset, :type, :detail_path

    def detail_url
      return nil if detail_path.blank?

      detail_path.call(asset)
    end

    def projekt_name
      resource_name(asset.projekt)
    end

    def projekt_url
      resource_url(asset.projekt)
    end

    def uploaded_by
      asset.user
    end

    def filename
      asset.data_file_name.presence || asset.title.presence || "Untitled"
    end

    def humanized_size
      return "" if asset.data_file_size.blank?

      helpers.number_to_human_size(asset.data_file_size)
    end

    def created_at_formatted
      I18n.l(asset.created_at, format: :short)
    end

    def updated_at_formatted
      I18n.l(asset.updated_at, format: :short)
    end

    def image?
      asset.data_content_type&.start_with?("image/")
    end

    def picture?
      type == "picture"
    end

    def alt_text
      asset.alt_text
    end

    def has_preview?
      asset.gallery_thumb_url.present?
    end

    def icon_class
      FileTypeIcons.for(asset.data_content_type)
    end

    def dimensions
      return "" if asset.width.blank?
      return "" if asset.height.blank?

      "#{asset.width} × #{asset.height}"
    end

    def delete_url
      if type == "picture"
        helpers.file_manager_image_path(asset)
      else
        helpers.file_manager_document_path(asset)
      end
    end
end
