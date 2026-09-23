module MachineTranslation
  module Tasks
    module_function

    def validate_locale!(locale, allow_source_locale: false)
      locale = locale.to_s
      permitted = MachineTranslation.translatable_locales
      permitted += [MachineTranslation.source_locale] if allow_source_locale

      unless permitted.map(&:to_s).include?(locale)
        abort "unknown target locale #{locale.inspect}; " \
              "available: #{permitted.join(", ")}"
      end

      locale
    end

    def pending_records(model, locale)
      model.find_each do |record|
        rows = MachineTranslation.all_translations(record).order(:created_at, :id).to_a
        next if rows.any? { |row| row.locale.to_s == locale }

        source_row = rows.first
        next if source_row.nil?

        yield(record, source_row)
      end
    end

    def pending_translation?(record, locale)
      RemoteTranslation.where(remote_translatable: record, locale: locale, error_message: nil).exists?
    end

    def characters_in(model, source_row)
      model.translated_attribute_names.sum { |field| source_row[field].to_s.length }
    end
  end
end
