class Adm::FileManager::PageComponent < ApplicationComponent
  renders_one :sub_header
  renders_one :description

  renders_one :types_note,
              ->(types:, note_key: "files.allowed_types_note_html", settings_link: false) do
    render(
      "adm/files/allowed_types_note",
      admin_types: types,
      user_types: types,
      note_key: note_key,
      show_settings_link: settings_link
    )
  end

  def initialize(
    type:,
    title:,
    breadcrumbs:,
    assets:,
    endpoint:,
    card_component: Files::AssetCardComponent,
    row_component: nil,
    frontend_url: nil,
    upload_endpoint: nil,
    upload_accept: nil,
    imageable_type_frame_src: nil,
    documentable_type_frame_src: nil
  )
    @type = type
    @title = title
    @breadcrumbs = breadcrumbs
    @assets = assets
    @endpoint = endpoint
    @card_component = card_component
    @row_component = row_component
    @frontend_url = frontend_url
    @upload_endpoint = upload_endpoint
    @upload_accept = upload_accept
    @imageable_type_frame_src = imageable_type_frame_src
    @documentable_type_frame_src = documentable_type_frame_src
  end

  private

    attr_reader :type, :title, :breadcrumbs, :assets, :endpoint,
                :card_component, :row_component, :frontend_url,
                :upload_endpoint, :upload_accept, :imageable_type_frame_src,
                :documentable_type_frame_src

    def after_title?
      description? || types_note? || upload?
    end

    def upload?
      upload_endpoint.present?
    end

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
