class Adm::LanguageSelectorComponent < ApplicationComponent
  def render?
    locales.size > 1
  end

  private

    def locales
      SupportedLocales::ADM.slice(*I18n.available_locales)
    end
end
