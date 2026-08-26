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
        return if options[:count].present?

        ChromeStore.lookup(locale, flat_key).presence
      rescue StandardError => e
        Sentry.capture_exception(e)
        nil
      end
  end
end
