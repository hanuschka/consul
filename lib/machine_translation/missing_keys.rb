module MachineTranslation
  module MissingKeys
    LIMIT = 5_000

    class << self
      def record(locale, key)
        return unless MachineTranslation.enabled?
        return unless MachineTranslation.target_locale?(locale)
        return unless MachineTranslation.translatable_key?(key)

        mutex.synchronize do
          bucket = pending[locale.to_s] ||= Set.new
          bucket << key if bucket.size < LIMIT
        end
      rescue StandardError => e
        Sentry.capture_exception(e)
        nil
      end

      def pending_for(locale)
        mutex.synchronize { (pending[locale.to_s] || Set.new).dup }
      end

      def drain(locale)
        mutex.synchronize { pending.delete(locale.to_s) || Set.new }
      end

      def clear
        mutex.synchronize { @pending = {} }
      end

      private

        def pending
          @pending ||= {}
        end

        def mutex
          @mutex ||= Mutex.new
        end
    end
  end
end
