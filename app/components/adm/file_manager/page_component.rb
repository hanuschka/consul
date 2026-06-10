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

  renders_one :upload, ->(endpoint:, accept: nil) do
    render(
      Adm::ButtonWithProgressComponent.new(
        label: t("files.card.upload"),
        loading_label: t("files.upload_loading"),
        success_label: t("files.upload_success"),
        icon: "upload",
        button_data: { action: "click->files--upload#triggerPicker" },
        extra_controllers: ["files--upload"],
        extra_root_data: { "files--upload-endpoint-value": endpoint }
      )
    ) do
      safe_join(
        [
          tag.input(
            type: "file",
            accept: accept,
            class: "js-files-upload-input",
            hidden: true,
            data: {
              "files--upload-target" => "input",
              "action" => "change->files--upload#fileChanged"
            }
          ),
          tag.span(
            "",
            hidden: true,
            data: { "files-upload-failed-message": t("files.upload_failed") }
          )
        ]
      )
    end
  end

  def initialize(type:, title:, breadcrumbs:, grid:, frontend_url: nil)
    @type = type
    @title = title
    @breadcrumbs = breadcrumbs
    @grid = grid
    @frontend_url = frontend_url
  end

  private

    attr_reader :type, :title, :breadcrumbs, :grid, :frontend_url

    def after_title?
      description? || types_note? || upload?
    end
end
