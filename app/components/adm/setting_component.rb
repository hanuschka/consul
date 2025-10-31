class Adm::SettingComponent < ApplicationComponent
  include Turbo::FramesHelper

  def initialize(setting:, kind:, path: nil, updated: false)
    @setting = setting
    @kind = kind
    @path = path
    @updated = updated
  end

  def set_path(path)
    return path if path.present?

    return adm_setting_path(@setting) if @setting.is_a?(Setting)
    return adm_site_customization_image_path(@setting) if @setting.is_a?(SiteCustomization::Image)
  end

  def component_for_type
    case @kind
    when :string
      Adm::Settings::StringComponent
    when :boolean
      Adm::Settings::BooleanComponent
    when :image
      Adm::Settings::ImageComponent
    else
      raise "Unknown setting type: #{@kind}"
    end
  end
end
