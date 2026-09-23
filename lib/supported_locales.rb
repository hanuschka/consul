module SupportedLocales
  BUNDLED = %i[de en].freeze
  ADM = { de: "Deutsch", en: "English" }.freeze

  def self.bundled?(locale)
    locale = locale&.to_sym

    BUNDLED.include?(locale) || locale == I18n.default_locale
  end

  def self.adm?(locale)
    ADM.key?(locale&.to_sym)
  end

  def self.served?(locale)
    bundled?(locale) || MachineTranslation.enabled?
  end
end
