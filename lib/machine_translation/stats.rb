module MachineTranslation
  module Stats
    USAGE_CACHE_KEY = "machine_translation/usage".freeze
    USAGE_CACHE_TTL = 5.minutes

    module_function

    def usage
      Rails.cache.fetch(USAGE_CACHE_KEY, expires_in: USAGE_CACHE_TTL) do
        Deepl::Client.new.usage
      end
    rescue StandardError
      nil
    end

    def expire_usage
      Rails.cache.delete(USAGE_CACHE_KEY)
    end

    def rows_per_locale
      MachineTranslation.translatable_models.each_with_object(Hash.new(0)) do |model, counts|
        model.translation_class.unscoped.group(:locale).count.each do |locale, count|
          counts[locale.to_s] += count
        end
      end
    end

    def chrome_rows_per_locale
      I18nContent.translation_class.unscoped.group(:locale).count.transform_keys(&:to_s)
    end

    def pending_count
      RemoteTranslation.where(error_message: nil).count
    end

    def failures
      RemoteTranslation.where.not(error_message: nil).order(updated_at: :desc)
    end

    def circuit_open?
      Deepl::CircuitBreaker.open?
    end

    def purge_locale(locale)
      deleted = 0

      MachineTranslation.translatable_models.each do |model|
        klass = model.translation_class
        table = klass.table_name
        foreign_key = klass.reflect_on_association(:globalized_model).foreign_key

        deleted += klass.unscoped.where(locale: locale).where(
          "EXISTS (SELECT 1 FROM #{table} older " \
          "WHERE older.#{foreign_key} = #{table}.#{foreign_key} " \
          "AND (older.created_at < #{table}.created_at " \
          "OR (older.created_at = #{table}.created_at AND older.id < #{table}.id)))"
        ).delete_all
      end

      deleted
    end
  end
end
