class Adm::Settings::ImageComponent < ApplicationComponent
  def initialize(setting:, path:, updated:)
    @setting = setting
    @path = path
    @updated = updated
  end

  def show_preview?
    @setting.image.attached? && !@setting.image.changed?
  end
end
