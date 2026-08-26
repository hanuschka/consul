module MachineTranslation
  DENIED_KEY_PREFIXES = %w[adm admin date datetime time number i18n support].freeze
  DENIED_KEYS = %w[errors.format activerecord.errors.format].freeze
  STRFTIME_DIRECTIVE = /%[-_0^#]?\d*[a-zA-Z]/.freeze
  INTERPOLATION = /%[{<][^}>]*[}>]s?/.freeze
  URL_ONLY = %r{\Ahttps?://\S+\z}.freeze

  def self.source_locale
    I18n.default_locale
  end

  def self.target_locale?(locale)
    locale = locale.to_sym

    locale != source_locale && I18n.available_locales.include?(locale)
  end

  def self.enabled?
    Deepl.configured?
  rescue StandardError
    false
  end

  def self.flat_key(key, scope, separator)
    return if key.blank?

    I18n.normalize_keys(nil, key, scope, separator).join(".")
  rescue StandardError
    nil
  end

  def self.translatable_key?(key)
    return false if key.blank?
    return false if DENIED_KEYS.include?(key)

    DENIED_KEY_PREFIXES.exclude?(key.split(".").first)
  end

  def self.translatable_value?(value)
    return false unless value.is_a?(String)
    return false if value.blank?
    return false if value.match?(URL_ONLY)
    return false unless value.match?(/[[:alpha:]]/)

    !value.gsub(INTERPOLATION, "").match?(STRFTIME_DIRECTIVE)
  end
end
