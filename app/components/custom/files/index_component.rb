class Files::IndexComponent < ApplicationComponent
  def initialize(
    type:,
    assets:,
    endpoint:,
    card_component: Files::AssetCardComponent,
    imageable_type_frame_src: nil,
    documentable_type_frame_src: nil
  )
    @type = type
    @assets = assets
    @endpoint = endpoint
    @card_component = card_component
    @imageable_type_frame_src = imageable_type_frame_src
    @documentable_type_frame_src = documentable_type_frame_src
  end

  private

    attr_reader :type, :assets, :endpoint, :card_component,
                :imageable_type_frame_src, :documentable_type_frame_src
end
