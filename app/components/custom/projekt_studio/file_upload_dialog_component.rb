class ProjektStudio::FileUploadDialogComponent < ApplicationComponent
  MODES = %w[picture document].freeze

  def initialize(type:)
    unless MODES.include?(type)
      raise ArgumentError, "unknown type #{type.inspect}, expected one of #{MODES.join(", ")}"
    end

    @type = type
  end

  private

  attr_reader :type

  def title_text
    return I18n.t("custom.studio.upload_image.title") if type == "picture"

    I18n.t("custom.studio.upload_document.title")
  end

  def upload_text
    return I18n.t("custom.studio.upload_image.button_label") if type == "picture"

    I18n.t("custom.studio.upload_document.button_label")
  end
end
