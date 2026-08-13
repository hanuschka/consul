module LocaleSwitching
  extend ActiveSupport::Concern

  private

    def switch_locale(&action)
      locale = current_locale

      if explicit_locale_param
        session[:locale] = locale
        persist_user_locale(locale)
      end

      I18n.with_locale(locale, &action)
    end

    def current_locale
      explicit_locale_param ||
        validate_locale(session[:locale]) ||
        validate_locale(current_user&.locale) ||
        browser_locale ||
        I18n.default_locale
    end

    def explicit_locale_param
      return @explicit_locale_param if defined?(@explicit_locale_param)

      @explicit_locale_param = validate_locale(params[:locale])
    end

    def validate_locale(value)
      return if value.blank?

      locale = value.to_s.to_sym
      locale if I18n.available_locales.include?(locale)
    end

    def persist_user_locale(locale)
      return if current_user.blank?
      return if current_user.locale == locale.to_s

      current_user.update_column(:locale, locale.to_s)
    end

    # "de-DE,de;q=0.9,en-US;q=0.8" -> the highest-weighted available locale.
    # Region variants fall back to their base language, so pt-BR selects :pt.
    def browser_locale
      header = request.headers["Accept-Language"]
      return if header.blank?

      browser_language_tags(header)
        .map { |tag| matching_available_locale(tag) }
        .compact
        .first
    end

    def browser_language_tags(header)
      header.split(",").filter_map { |part|
        tag, quality = part.split(/;\s*q\s*=/i)
        tag = tag.to_s.strip
        next if tag.blank? || tag == "*"

        [tag, (quality || "1").to_f]
      }.each_with_index.sort_by { |(_tag, quality), index| [-quality, index] }
        .map { |(tag, _quality), _index| tag }
    end

    def matching_available_locale(tag)
      base = tag.split("-").first

      I18n.available_locales.find { |locale| locale.to_s.casecmp?(tag) } ||
        I18n.available_locales.find { |locale| locale.to_s.casecmp?(base) } ||
        I18n.available_locales.find { |locale| locale.to_s.split("-").first.casecmp?(base) }
    end
end
