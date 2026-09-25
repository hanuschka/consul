class Admin::SiteCustomization::InformationTextsController < Admin::SiteCustomization::BaseController
  before_action :delete_translations, only: [:update]

  def index
    @tab = params[:tab] || :basic
    @content = I18nContent.content_for(@tab)
  end

  def update
    I18nContent.update(content_params, enabled_translations)

    redirect_to admin_site_customization_information_texts_path,
                notice: t("flash.actions.update.translation")
  end

  private

    def resource
      I18nContent.find(content_params[:id])
    end

    def content_params
      params.require(:contents).values
    end

    def delete_translations
      languages_to_delete = params[:enabled_translations].select { |_, v| v == "0" }.keys
      kept_locales = languages_to_delete & machine_translated_locales

      (languages_to_delete - kept_locales).each do |locale|
        I18nContentTranslation.where(locale: locale).destroy_all
      end

      announce_kept_locales(kept_locales)
    end

    def announce_kept_locales(locales)
      return if locales.empty?

      flash[:alert] = t("flash.actions.update.translation_locked",
                        locales: locales.map { |locale| helpers.name_for_locale(locale) }.to_sentence)
    end

    def enabled_translations
      params.fetch(:enabled_translations, {}).select { |_, v| v == "1" }.keys
    end

    def machine_translated_locales
      return [] unless MachineTranslation.enabled?

      MachineTranslation.translatable_locales.map(&:to_s)
    end
end
