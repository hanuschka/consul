class Files::AssetCardComponent < ApplicationComponent
  with_collection_parameter :asset

  def initialize(asset:, type:)
    @asset = asset
    @type = type
  end

  private

    attr_reader :asset, :type

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
end
