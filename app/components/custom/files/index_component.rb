class Files::IndexComponent < ApplicationComponent
  def initialize(type:, grid:)
    @type = type
    @assets = grid[:assets]
    @endpoint = grid[:endpoint]
    @card_component = grid[:card_component] || Files::AssetCardComponent
    @row_component = grid[:row_component]
    @imageable_type_frame_src = grid[:imageable_type_frame_src]
    @documentable_type_frame_src = grid[:documentable_type_frame_src]
  end

  private

    attr_reader :type, :assets, :endpoint, :card_component, :row_component,
                :imageable_type_frame_src, :documentable_type_frame_src

    def supports_view_modes?
      row_component.present?
    end

    def images?
      type == "picture"
    end

    def empty_title
      images? ? t("files.empty.images.title") : t("files.empty.documents.title")
    end

    def empty_description
      images? ? t("files.empty.images.description") : t("files.empty.documents.description")
    end

    def empty_icon
      images? ? "image" : "description"
    end
end
