class Shared::ProjektSelectableSettingComponent < ApplicationComponent
  def initialize(setting:, options:, tab: nil, i18n_key:)
    @selectable_setting = setting
    @options = options
    @tab = tab
    @i18n_key = i18n_key
  end

  private

    def render?
      @selectable_setting.present?
    end

    def translated_options
      @options.map { |o| [I18n.t("#{@i18n_key}_options.#{o}"), o] }
    end
end
