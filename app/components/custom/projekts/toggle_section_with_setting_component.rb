class Projekts::ToggleSectionWithSettingComponent < ViewComponent::Base
  def initialize(setting_key:, projekt:, enable: false, setting_active:, other_conditions_are_met: true)
    @enable = enable
    @projekt = projekt
    @setting_key = setting_key
    @setting_active = setting_active
    @other_conditions_are_met = other_conditions_are_met
  end

  def get_setting_id
    @projekt.projekt_settings.find_by(key: @setting_key).id
  end

  def default_title
    @setting_active ? on_title : off_title
  end

  def on_title

  end

  def off_title

  end

  def disabled_class
    @setting_active ? "" : "-deactivated"
  end

  def icon_class
    @setting_active ? "fa-eye-slash" : "fa-eye"
  end
end
