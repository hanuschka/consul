class RemoteTranslations::Caller
  attr_reader :remote_translation

  def initialize(remote_translation, source_locale: nil, backfill: false)
    @remote_translation = remote_translation
    @source_locale = source_locale
    @backfill = backfill
  end

  def call
    written = MachineTranslation.suppress do
      ActiveRecord::Base.no_touching { write_translation }
    end

    resource.touch if written && !backfill?
    remote_translation.destroy
  rescue StandardError => e
    remote_translation.update(error_message: "#{e.class}: #{e.message}")
  end

  private

    def backfill?
      @backfill
    end

    def write_translation
      return false if hidden_resource?

      row = existing_row
      return false if row&.hidden_at.present?

      row ||= resource.translations.new(locale: locale)

      resource.translated_attribute_names.each_with_index do |field, index|
        row[field] = translated_values[index]
      end

      return false unless row.changed?

      row.save!
      true
    end

    def hidden_resource?
      resource.respond_to?(:hidden?) && resource.hidden?
    end

    def existing_row
      resource.translations.with_deleted.find_by(locale: locale)
    end

    def resource
      @resource ||= remote_translation.remote_translatable
    end

    def translated_values
      @translated_values ||= Deepl::Client.new.translate(fields_values,
                                                         target_locale: locale,
                                                         source_locale: deepl_source_locale,
                                                         tag_handling: "html")
    end

    def fields_values
      Globalize.with_locale(source_locale) do
        resource.translated_attribute_names.map { |field| resource.send(field) }
      end
    end

    def locale
      remote_translation.locale
    end

    def source_locale
      @source_locale.presence || authored_locale || MachineTranslation.source_locale
    end

    def authored_locale
      resource.translations.order(:created_at, :id).first&.locale
    end

    def deepl_source_locale
      source_locale if Deepl::Languages.supported?(source_locale)
    end
end
