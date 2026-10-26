module MachineTranslation
  module I18nBackend
    def lookup(locale, key, scope = [], options = I18n::EMPTY_HASH)
      flat_key = MachineTranslation.flat_key(key, scope, options[:separator])
      stored = machine_translation_stored_value(locale, flat_key, options)

      return stored unless stored.nil?

      super.tap do |result|
        MissingKeys.record(locale, flat_key) if result.nil?
      end
    end

    private

      def machine_translation_stored_value(locale, flat_key, options)
        return if flat_key.nil?

        pluralized = if options[:count].present?
                       machine_translation_pluralized_value(locale, flat_key, options[:count])
                     end

        pluralized || ChromeStore.lookup(locale, flat_key).presence
      rescue StandardError => e
        Sentry.capture_exception(e)
        nil
      end

      def machine_translation_pluralized_value(locale, flat_key, count)
        values = ChromeStore.values(locale)
        required = MachineTranslation.plural_category(locale, count)

        return if values["#{flat_key}.#{required}"].blank?

        MachineTranslation::PLURAL_CATEGORIES.filter_map { |category|
          value = values["#{flat_key}.#{category}"]

          [category, value] if value.present?
        }.to_h.presence
      end
  end
end
