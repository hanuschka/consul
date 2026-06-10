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
    grid:,
    frontend_url: nil,
    upload_endpoint: nil,
    upload_accept: nil
  )
    @type = type
    @title = title
    @breadcrumbs = breadcrumbs
    @grid = grid
    @frontend_url = frontend_url
    @upload_endpoint = upload_endpoint
    @upload_accept = upload_accept
  end

  private

    attr_reader :type, :title, :breadcrumbs, :grid, :frontend_url,
                :upload_endpoint, :upload_accept

    def after_title?
      description? || types_note? || upload?
    end

    def upload?
      upload_endpoint.present?
    end
end
