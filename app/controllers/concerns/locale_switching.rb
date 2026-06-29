module LocaleSwitching
  extend ActiveSupport::Concern

  private

    def switch_locale(&action)
      locale = current_locale

      if current_user && current_user.locale != locale.to_s
        current_user.update(locale: locale)
      end

      session[:locale] = locale
      I18n.with_locale(locale, &action)
    end

    def current_locale
      if I18n.available_locales.include?(params[:locale]&.to_sym)
        params[:locale]
      elsif I18n.available_locales.include?(session[:locale]&.to_sym)
        session[:locale]
      else
        I18n.default_locale
      end
    end
end
