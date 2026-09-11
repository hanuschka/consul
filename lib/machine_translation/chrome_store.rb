module MachineTranslation
  module ChromeStore
    REVALIDATE_AFTER = 60

    class << self
      def lookup(locale, key)
        values(locale)[key]
      end

      def values(locale)
        locale = locale.to_s
        revalidate

        mutex.synchronize { cache[locale] ||= load(locale) }
      end

      def reset!
        mutex.synchronize do
          @cache = {}
          @signature = nil
          @checked_at = nil
        end
      end

      private

        def revalidate
          return if @checked_at && monotonic_now - @checked_at < REVALIDATE_AFTER

          current = signature
          @checked_at = monotonic_now

          return if current == @signature

          mutex.synchronize do
            @cache = {}
            @signature = current
          end
        end

        def load(locale)
          I18nContent
            .joins(:translations)
            .where(i18n_content_translations: { locale: locale })
            .pluck("i18n_contents.key", "i18n_content_translations.value")
            .to_h
            .compact
        rescue ActiveRecord::ActiveRecordError
          {}
        end

        def signature
          translations = I18nContent.translation_class

          [translations.count, translations.maximum(:updated_at)]
        rescue ActiveRecord::ActiveRecordError
          nil
        end

        def cache
          @cache ||= {}
        end

        def mutex
          @mutex ||= Mutex.new
        end

        def monotonic_now
          Process.clock_gettime(Process::CLOCK_MONOTONIC)
        end
    end
  end
end
