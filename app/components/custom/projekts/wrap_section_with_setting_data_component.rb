class Projekts::WrapSectionWithSettingDataComponent < ViewComponent::Base
  def initialize(setting_key:, enable: false, setting_active:, other_conditions_are_met: true)
    @enable = enable
    @setting_key = setting_key
    @setting_active = setting_active
    @other_conditions_are_met = other_conditions_are_met
  end

  def disabled_class
    @setting_active ? "" : "-deactivated"
  end

  def icon_class
    @setting_active ? "fa-eye-slash" : "fa-eye"
  end
end
