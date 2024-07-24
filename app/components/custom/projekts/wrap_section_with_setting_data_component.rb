class Projekts::WrapSectionWithSettingDataComponent < ViewComponent::Base
  def initialize(setting_key:, enable: false, setting_active:, other_conditions_are_met: true)
    @enable = enable
    @setting_key = setting_key
    @setting_active = setting_active
    @other_conditions_are_met = other_conditions_are_met
  end

  def call
    if @enable
      content_tag(
        :div,
        class: "js-projekt-section-data-wrapper #{disabled_class} projekt-section-data-wrapper",
        data: {
          projekt_setting_key: @setting_key, projekt_setting_active: @setting_active,
          other_conditions_are_met: @other_conditions_are_met
        }
      ) do
        content
      end
    else
      content
    end
  end

  def disabled_class
    return "-deactivated" if !@setting_active
  end
end
