class Adm::SettingComponent < ApplicationComponent
  include Turbo::FramesHelper

  def initialize(setting_class:, key:, kind:, path: nil, updated: false)
    @setting = setting_class.constantize.find_by(key: key)
    @kind = kind
    @path = path
    @updated = updated
  end

  def path
    return @path if @path.present?

    raise "Cannot determine path without klass" if @setting.nil?

    adm_setting_path(@setting) if @setting.present? && @setting.is_a?(Setting)
  end

  def component_for_type
    case @kind
    when :string
      Adm::Settings::StringComponent
    when "boolean"
      Adm::Settings::BooleanComponent
    else
      raise "Unknown setting type: #{@kind}"
    end
  end
end
