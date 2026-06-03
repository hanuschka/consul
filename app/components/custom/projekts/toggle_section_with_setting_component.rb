class Projekts::ToggleSectionWithSettingComponent < ViewComponent::Base
  def initialize(setting_key:, projekt:, enable: false, setting_active:)
    @enable = enable
    @projekt = projekt
    @setting_key = setting_key
    @setting_active = setting_active
  end

  def render?
    content.present?
  end

  def get_setting_id
    @projekt.projekt_settings.find_by(key: @setting_key).id
  end

  def default_title
    @setting_active ? on_title : off_title
  end

  def on_title
    I18n.t("custom.projekts.sidebar_section.hide")
  end

  def off_title
    I18n.t("custom.projekts.sidebar_section.show")
  end

  def disabled_class
    @setting_active ? "" : "-deactivated"
  end

  def icon_class
    @setting_active ? "fa-eye-slash" : "fa-eye"
  end
end
