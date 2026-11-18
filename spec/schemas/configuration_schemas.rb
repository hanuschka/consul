# frozen_string_literal: true

module Schemas
  module Configuration
    TRANSLATIONS_DESCRIPTION =
      "Texts per language, keyed by locale (`de`, `en`). Each language is " \
      "written as given; languages that are left out stay as they are. When " \
      "more than one language is sent, automatic machine translation is " \
      "skipped so it cannot overwrite them."

    # OpenAPI description of one configurable key, generated from the same
    # ConfigurableKey the endpoint validates against.
    def self.configurable_key_property(configurable_key)
      value_definition = configurable_key.value_definition
      property = type_property(configurable_key)
      type_description = "#{configurable_key.type} (#{configurable_key.group})"

      property.merge(
        nullable: value_definition.allow_blank || nil,
        minimum: value_definition.min,
        maximum: value_definition.max,
        description: [type_description, property[:description]].compact.join(". ")
      ).compact
    end

    def self.type_property(configurable_key)
      value_definition = configurable_key.value_definition

      case configurable_key.type
      when :boolean then { type: :boolean }
      when :integer then { type: :integer }
      when :decimal then { type: :number }
      when :color then { type: :string, pattern: TypedValueParser::COLOR_FORMAT.source, example: "#004a83" }
      when :url then { type: :string, format: :uri, maxLength: TypedValueParser::URL_MAX_LENGTH }
      when :link then { type: :string, description: "Absolute http(s) URL or a path starting with /" }
      when :string
        { type: :string, maxLength: value_definition.max_length || TypedValueParser::STRING_MAX_LENGTH }
      when :text
        { type: :string, maxLength: value_definition.max_length || TypedValueParser::TEXT_MAX_LENGTH }
      when :select then select_property(value_definition.options)
      when :multi_select
        { type: :array, items: { type: :string, enum: value_definition.options.map(&:to_s) } }
      when :date then { type: :string, format: :date }
      end
    end

    def self.select_property(options)
      if options.empty?
        { type: :string }
      else
        { type: :string, enum: options.map(&:to_s) }
      end
    end
    
    # The keys every phase type accepts, merged: a key appears once, with the
    # type it has in the first phase type that lists it.
    def self.all_phase_configurable_keys
      ProjektPhase::PROJEKT_PHASES_TYPES.reverse.reduce({}) do |configurable_keys, phase_type|
        phase_keys = ProjektPhaseSetting::ConfigurableKeys.for_phase(phase_type.safe_constantize.new)
    
        configurable_keys.merge(phase_keys)
      end
    end
    
    def self.configurable_keys_object(configurable_keys)
      {
        type: :object,
        additionalProperties: false,
        properties: configurable_keys.values.to_h do |configurable_key|
          [configurable_key.key, configurable_key_property(configurable_key)]
        end
      }
    end

    def self.translations_object(attribute_properties)
      {
        type: :object,
        description: TRANSLATIONS_DESCRIPTION,
        additionalProperties: false,
        properties: I18n.available_locales.to_h do |locale|
          [locale.to_s, { type: :object, properties: attribute_properties }]
        end
      }
    end

    SETTING_ENTRY_SCHEMA = {
      type: :object,
      properties: {
        key: { type: :string, example: "brand_color" },
        group: { type: :string, enum: Setting::ConfigurableKeys::GROUPS, example: "branding" },
        type: { type: :string, enum: TypedValueParser::TYPES.map(&:to_s), example: "color" },
        options: { type: :array, items: { type: :string }, nullable: true },
        allow_blank: { type: :boolean },
        value: { nullable: true, description: "Current value, typed as `type` says", example: "#004a83" }
      },
      required: %w[key group type allow_blank]
    }.freeze

    VALIDATION_ERROR_SCHEMA = {
      type: :object,
      properties: {
        error: {
          type: :object,
          properties: {
            type: { type: :string, example: "unprocessable_entity" },
            messages: { type: :array, items: { type: :string } },
            details: {
              type: :object,
              description: "Error messages per key or attribute",
              additionalProperties: { type: :array, items: { type: :string } }
            }
          }
        }
      }
    }.freeze

    def self.all
      {
        ConfigurationSettingEntry: SETTING_ENTRY_SCHEMA,
        ConfigurationSettingsUpdate: configurable_keys_object(Setting::ConfigurableKeys.all),
        ConfigurationValidationError: VALIDATION_ERROR_SCHEMA,
        ProjektSettingsUpdate: configurable_keys_object(ProjektSetting::ConfigurableKeys.for_projekt(Projekt.new)),
        ProjektPhaseSettingsUpdate: configurable_keys_object(all_phase_configurable_keys)
      }
    end
  end
end
