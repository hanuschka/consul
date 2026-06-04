class Adm::LanguageSelectorComponent < ApplicationComponent
  LOCALES = { de: "Deutsch", en: "English" }.freeze

  def render?
    (Rails.env.development? || Rails.env.staging?) && locales.size > 1
  end

  private

    def locales
      LOCALES.slice(*I18n.available_locales)
    end
end
