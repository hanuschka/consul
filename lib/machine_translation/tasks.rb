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
      MachineTranslation.attribute_names(model).sum { |field| source_row[field].to_s.length }
    end

    def untranslated_attribute_rows(model, locale)
      fields = MachineTranslation.attribute_names(model)

      model.find_each do |record|
        rows = MachineTranslation.all_translations(record).order(:created_at, :id).to_a
        source_row = rows.first
        target_row = rows.find { |row| row.locale.to_s == locale }
        next if source_row.nil? || target_row.nil? || target_row == source_row
        next if MachineTranslation.hidden_row?(target_row)

        values = fields.flat_map { |field| MachineTranslation::HtmlAttributes.extract(source_row[field]) }.uniq
        remaining = fields.flat_map { |field| MachineTranslation::HtmlAttributes.extract(target_row[field]) }
        values &= remaining
        next if values.empty?

        yield(record, source_row, target_row, values)
      end
    end

    def translate_attributes!(model, source_row, target_row, values)
      translations = MachineTranslation::HtmlAttributes.translate(
        values, target_locale: target_row.locale.to_s,
                source_locale: (source_row.locale.to_s if Deepl::Languages.supported?(source_row.locale))
      )

      MachineTranslation.attribute_names(model).each do |field|
        target_row[field] = MachineTranslation::HtmlAttributes.apply(target_row[field], translations)
      end

      return false unless target_row.changed?

      MachineTranslation.suppress { ActiveRecord::Base.no_touching { target_row.save! } }
      true
    end
  end
end
