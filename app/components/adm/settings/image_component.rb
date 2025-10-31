class Adm::Settings::ImageComponent < ApplicationComponent
  def initialize(setting:, path:, updated:)
    @setting = setting
    @path = path
    @updated = updated
  end

  def signed_blob_id(form)
    return nil if @setting.errors[:image].any?

    @setting.image.blob.signed_id if @setting.image.attached?
  end
end
