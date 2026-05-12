class ProjektStudio::FileUploadDialogComponent < ApplicationComponent
  MODE_CONFIGS = {
    "picture" => {
      title_text: "Bilder verwalten",
      upload_text: "Bild hochladen"
    },
    "document" => {
      title_text: "Dokumente verwalten",
      upload_text: "Dokument hochladen"
    }
  }.freeze

  def initialize(type:)
    @type = type
  end

  private

  attr_reader :type

  def mode_config
    MODE_CONFIGS.fetch(type)
  end
end
