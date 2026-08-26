class MachineTranslation::Enqueuer
  def initialize(translation)
    @translation = translation
  end

  def call
    return unless MachineTranslation.enabled?
    return if MachineTranslation.suppressed?
    return if resource.nil?
    return unless content_changed?
    return if hidden_resource?

    target_locales.each { |target_locale| enqueue(target_locale) }
  end

  private

    attr_reader :translation

    def resource
      @resource ||= translation.globalized_model
    end

    def source_locale
      translation.locale
    end

    def content_changed?
      translated_attribute_names.intersect?(translation.saved_changes.keys)
    end

    def translated_attribute_names
      resource.translated_attribute_names.map(&:to_s)
    end

    def hidden_resource?
      resource.respond_to?(:hidden?) && resource.hidden?
    end

    def target_locales
      MachineTranslation.translatable_locales - [source_locale.to_sym]
    end

    def enqueue(target_locale)
      return if pending?(target_locale)

      remote_translation = RemoteTranslation.new(remote_translatable: resource, locale: target_locale.to_s)
      remote_translation.source_locale = source_locale
      remote_translation.save
    end

    def pending?(target_locale)
      RemoteTranslation.where(remote_translatable: resource,
                              locale: target_locale.to_s,
                              error_message: nil).exists?
    end
end
