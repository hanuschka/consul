# Globalize keeps the errors of a language's own row (a title missing in
# German) on that row, so the record's full messages alone come back empty.
module TranslatedRecordErrors
  def self.full_messages(record)
    translation_messages =
      record.translations.flat_map do |translation|
        translation.errors.full_messages.map { |message| "translations.#{translation.locale}: #{message}" }
      end

    record.errors.full_messages + translation_messages
  end
end
