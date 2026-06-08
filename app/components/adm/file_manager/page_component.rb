class Adm::FileManager::PageComponent < ApplicationComponent
  renders_one :sub_header

  def initialize(
    type:,
    title:,
    breadcrumbs:,
    assets:,
    endpoint:,
    card_component:,
    row_component: nil,
    description: nil,
    frontend_url: nil,
    upload_endpoint: nil,
    upload_accept: nil,
    allowed_types: nil,
    allowed_user_types: nil,
    allowed_types_note_key: "files.allowed_types_note_html",
    types_settings_link: false,
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
    @description = description
    @frontend_url = frontend_url
    @upload_endpoint = upload_endpoint
    @upload_accept = upload_accept
    @allowed_types = allowed_types
    @allowed_user_types = allowed_user_types
    @allowed_types_note_key = allowed_types_note_key
    @types_settings_link = types_settings_link
    @imageable_type_frame_src = imageable_type_frame_src
    @documentable_type_frame_src = documentable_type_frame_src
  end

  private

    attr_reader :type, :title, :breadcrumbs, :assets, :endpoint,
                :card_component, :row_component, :description, :frontend_url,
                :upload_endpoint, :upload_accept, :allowed_types,
                :allowed_user_types, :allowed_types_note_key, :types_settings_link,
                :imageable_type_frame_src, :documentable_type_frame_src

    def after_title?
      description.present? || allowed_types_note? || upload?
    end

    def allowed_types_note?
      allowed_types.present?
    end

    def upload?
      upload_endpoint.present?
    end
end
