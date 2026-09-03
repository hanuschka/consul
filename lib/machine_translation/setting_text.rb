module MachineTranslation
  module SettingText
    NAMESPACE = "machine_setting".freeze
    TIMEOUT = 2
    FAILURE_TTL = 3600
    MUTEX = Mutex.new

    ALLOWED_KEYS = %w[
      extended_option.general.title
      extended_option.general.subtitle
      extended_option.general.homepage_button_text
      deficiency_reports.create_cta
      deficiency_reports.feature_name
      deficiency_reports.new_form_title
      deficiency_reports.new_form_title_placeholder
      meta_title
      meta_description
      meta_keywords
      proposals.email_short_title
      proposals.email_description
      proposals.poll_short_title
      proposals.poll_description
      proposals.poster_short_title
      proposals.poster_description
    ].freeze

    class << self
      def call(key)
        value = Setting[key]
        return value unless translatable?(key, value)

        locale = I18n.locale
        content_key = content_key_for(key, value)

        cached(locale, content_key) || stored(locale, content_key) ||
          translate_and_store(content_key, value, locale) || value
      end

      def content_key_for(key, value)
        "#{NAMESPACE}.#{key}.#{digest(value)}"
      end

      def stale_content_keys
        current = Setting.all.pluck(:key, :value).to_h.slice(*ALLOWED_KEYS)
        live = current.filter_map { |key, value| content_key_for(key, value) if value.present? }

        I18nContent.where("key LIKE ?", "#{NAMESPACE}.%").where.not(key: live).pluck(:key)
      end

      def reset!
        MUTEX.synchronize { @failures = {} }
      end

      private

        def translatable?(key, value)
          ALLOWED_KEYS.include?(key.to_s) &&
            value.present? &&
            MachineTranslation.enabled? &&
            MachineTranslation.translatable_locales.include?(I18n.locale) &&
            MachineTranslation.translatable_value?(value)
        end

        def digest(value)
          Digest::SHA256.hexdigest(value)[0, 8]
        end

        def cached(locale, content_key)
          ChromeStore.lookup(locale, content_key).presence
        end

        def stored(locale, content_key)
          I18nContent
            .joins(:translations)
            .where(key: content_key, i18n_content_translations: { locale: locale.to_s })
            .pick("i18n_content_translations.value")
            .presence
        rescue ActiveRecord::ActiveRecordError
          nil
        end

        def translate_and_store(content_key, value, locale)
          return if blocked?(content_key, locale)

          translated = translate(value, locale)

          if translated.blank?
            record_failure(content_key, locale)
            return
          end

          record_failure(content_key, locale) unless store(content_key, translated, locale)
          translated
        rescue StandardError => e
          record_failure(content_key, locale)
          report(e, content_key)
          nil
        end

        def report(error, content_key)
          return if error.is_a?(Deepl::CircuitOpenError)

          Deepl::ErrorReporter.report_exception(error, context: content_key)
        end

        def translate(value, locale)
          mode = TextMode.mode_for(value)

          attempt(value, locale, mode) || retry_attempt(value, locale, mode)
        end

        def retry_attempt(value, locale, mode)
          fallback = TextMode.fallback_for(mode)
          return if fallback.nil?

          attempt(value, locale, fallback)
        end

        def attempt(value, locale, mode)
          raw = request(TextMode.prepare(value, mode), locale, TextMode.options(mode))
          return if raw.blank?

          output = TextMode.restore(raw, mode)
          output if MachineTranslation.placeholders_intact?(value, output)
        end

        def request(text, locale, options)
          Deepl::Client.new(open_timeout: TIMEOUT, read_timeout: TIMEOUT)
            .translate([text],
                       target_locale: locale,
                       source_locale: MachineTranslation.source_locale,
                       **options)
            .first
        end

        def store(content_key, translated, locale)
          MachineTranslation.store_content(content_key, translated, locale)
        rescue ActiveRecord::ActiveRecordError
          false
        end

        def blocked?(content_key, locale)
          deadline = MUTEX.synchronize { failures[[locale.to_s, content_key]] }

          deadline.present? && monotonic_now < deadline
        end

        def record_failure(content_key, locale)
          MUTEX.synchronize do
            now = monotonic_now
            failures.delete_if { |_, deadline| deadline <= now }
            failures[[locale.to_s, content_key]] = now + FAILURE_TTL
          end
        end

        def failures
          @failures ||= {}
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
    end
  end
end
