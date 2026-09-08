module RemoteTranslationsHelper
  def display_remote_translation_info?(remote_translations, locale)
    remote_translations.present? && MachineTranslation.translatable_locales.include?(locale.to_sym)
  end

  def display_remote_translation_button?(remote_translations)
    remote_translations.none? do |remote_translation|
      RemoteTranslation.remote_translation_enqueued?(remote_translation)
    end
  end
end
