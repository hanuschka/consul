class RemoteTranslations::Caller
  attr_reader :remote_translation

  def initialize(remote_translation, source_locale: nil)
    @remote_translation = remote_translation
    @source_locale = source_locale
  end

  def call
    update_resource
    destroy_remote_translation
  end

  private

    def update_resource
      Globalize.with_locale(locale) do
        resource.translated_attribute_names.each_with_index do |field, index|
          resource.send(:"#{field}=", translations[index])
        end
      end
      resource.save
    end

    def destroy_remote_translation
      if resource.valid?
        remote_translation.destroy
        resource.save!
      else
        remote_translation.update(error_message: resource.errors.messages)
      end
    end

    def resource
      @resource ||= remote_translation.remote_translatable
    end

    def translations
      @translations ||= Deepl::Client.new.translate(fields_values,
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
