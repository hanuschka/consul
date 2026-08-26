module MachineTranslation
  DENIED_KEY_PREFIXES = %w[adm admin date datetime time number i18n support].freeze
  DENIED_KEYS = %w[errors.format activerecord.errors.format].freeze
  STRFTIME_DIRECTIVE = /%[-_0^#]?\d*[a-zA-Z]/.freeze
  INTERPOLATION = /%\{[^{}]*\}|%<\w+>[a-zA-Z]/.freeze
  URL_ONLY = %r{\Ahttps?://\S+\z}.freeze

  def self.source_locale
    I18n.default_locale
  end

  def self.target_locale?(locale)
    locale = locale.to_sym

    locale != source_locale && I18n.available_locales.include?(locale)
  end

  def self.target_locales
    I18n.available_locales.map(&:to_sym) - [source_locale]
  end

  def self.translatable_locales
    target_locales.select { |locale| Deepl::Languages.supported?(locale) }
  end

  PLURAL_CATEGORIES = %i[zero one two few many other].freeze
  SETTING_KEY = "extended_feature.general.machine_translation".freeze
  SUPPRESSION_KEY = :machine_translation_suppressed

  def self.enabled?
    Deepl.configured? && Setting[SETTING_KEY].present?
  rescue StandardError
    false
  end

  def self.all_translations(record)
    scope = record.translations

    scope.respond_to?(:with_deleted) ? scope.with_deleted : scope
  end

  def self.authored_locale(record)
    all_translations(record).order(:created_at, :id).first&.locale
  end

  def self.hidden_row?(row)
    row.respond_to?(:hidden_at) && row.hidden_at.present?
  end

  def self.translatable_models
    Rails.application.eager_load!

    ApplicationRecord.descendants.select do |model|
      model.include?(MachineTranslatable) && model.name.present? && model.base_class == model
    end.sort_by(&:name)
  end

  def self.plural_category(locale, count)
    backend = I18n.backend

    if backend.respond_to?(:pluralizer, true)
      rule = backend.send(:pluralizer, locale)
      return rule.call(count) if rule.respond_to?(:call)
    end

    count == 1 ? :one : :other
  rescue StandardError
    count == 1 ? :one : :other
  end

  def self.suppress
    previous = Thread.current[SUPPRESSION_KEY]
    Thread.current[SUPPRESSION_KEY] = true
    yield
  ensure
    Thread.current[SUPPRESSION_KEY] = previous
  end

  def self.all_translations(record)
    scope = record.translations

    scope.respond_to?(:with_deleted) ? scope.with_deleted : scope
  end

  def self.authored_locale(record)
    all_translations(record).order(:created_at, :id).first&.locale
  end

  def self.hidden_row?(row)
    row.respond_to?(:hidden_at) && row.hidden_at.present?
  end

  def self.translatable_models
    Rails.application.eager_load!

    ApplicationRecord.descendants.select do |model|
      model.include?(MachineTranslatable) && model.name.present? && model.base_class == model
    end.sort_by(&:name)
  end

  def self.plural_category(locale, count)
    backend = I18n.backend

    if backend.respond_to?(:pluralizer, true)
      rule = backend.send(:pluralizer, locale)
      return rule.call(count) if rule.respond_to?(:call)
    end

    count == 1 ? :one : :other
  rescue StandardError
    count == 1 ? :one : :other
  end

  def self.suppressed?
    Thread.current[SUPPRESSION_KEY].present?
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
