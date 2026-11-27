class Api::Configuration::TextsController < Api::Configuration::BaseController
  DEFAULT_PER_PAGE = 100
  DENIED_KEY_PREFIX = "machine_setting.".freeze
  UNKNOWN_KEY_MESSAGE = "is not an editable interface text".freeze
  VALUE_DEFINITION = TypedValueParser::Definition.new(type: :text, allow_blank: true, max_length: 5000)

  class << self
    # The texts of the editable groups as the bundled YAML files define them,
    # flattened to dotted keys. They only change with a deploy, so they are
    # built once per process and locale.
    def bundled_texts(locale)
      @bundled_texts ||= {}
      @bundled_texts[locale.to_s] ||= build_bundled_texts(locale)
    end

    private

      def build_bundled_texts(locale)
        flat_texts =
          I18nContent::EDITABLE_GROUPS.each_with_object({}) do |group, texts|
            group_texts = I18n.t(group, locale:, default: nil, fallback: false)

            if group_texts.is_a?(Hash)
              I18nContent.flat_hash(group_texts, group.to_s, texts)
            end
          end

        flat_texts.select { |key, value| value.is_a?(String) && !key.start_with?(DENIED_KEY_PREFIX) }.freeze
      end
  end

  def index
    text_keys = paginate(Kaminari.paginate_array(filtered_keys), default_per_page: DEFAULT_PER_PAGE)
    contents_by_key = I18nContent.includes(:translations).where(key: text_keys.to_a).index_by(&:key)

    render json: {
      data: { texts: text_keys.map { |key| serialize(key, contents_by_key[key]) } },
      pagination: pagination_meta(text_keys)
    }
  end

  def update
    parsed_texts, errors = parse_texts

    if errors.any?
      render_invalid_values(errors)

      return
    end

    write_texts(parsed_texts)
    contents_by_key = I18nContent.includes(:translations).where(key: parsed_texts.keys).index_by(&:key)

    render json: {
      data: { texts: parsed_texts.keys.map { |key| serialize(key, contents_by_key[key]) } }
    }
  end

  private

    def editable_keys
      @editable_keys ||=
        available_locales.flat_map { |locale| self.class.bundled_texts(locale).keys }.uniq.sort
    end

    def filtered_keys
      prefix = params[:prefix].is_a?(String) ? params[:prefix] : ""

      editable_keys.select { |key| key.start_with?(prefix) }
    end

    def serialize(key, content)
      stored_values =
        content&.translations.to_a.to_h { |translation| [translation.locale.to_s, translation.value] }

      {
        key: key,
        translations: available_locales.index_with do |locale|
          {
            value: stored_values[locale].presence,
            default: self.class.bundled_texts(locale)[key]
          }
        end
      }
    end

    def texts_param
      texts = params.require(:texts)

      if texts.is_a?(ActionController::Parameters)
        texts.to_unsafe_h
      else
        raise ActionController::ParameterMissing, :texts
      end
    end

    def parse_texts
      editable_key_set = editable_keys.to_set
      parsed_texts = {}
      errors = {}

      texts_param.each do |key, values_by_locale|
        key_errors = text_errors(key, values_by_locale, editable_key_set)

        if key_errors.any?
          errors[key] = key_errors
        else
          parsed_texts[key] = parsed_values(key, values_by_locale)
        end
      end

      [parsed_texts, errors]
    end

    def text_errors(key, values_by_locale, editable_key_set)
      if !editable_key_set.include?(key)
        [UNKNOWN_KEY_MESSAGE]
      elsif !values_by_locale.is_a?(Hash) || values_by_locale.empty?
        ["must map languages (#{available_locales.join(", ")}) to texts"]
      else
        values_by_locale.filter_map do |locale, raw_value|
          locale_value_error(locale, raw_value)
        end
      end
    end

    def locale_value_error(locale, raw_value)
      if !available_locales.include?(locale)
        "#{locale} is not a supported language"
      else
        result = TypedValueParser.parse(raw_value, VALUE_DEFINITION)

        if !result.valid?
          "#{locale} #{result.error}"
        end
      end
    end

    def parsed_values(key, values_by_locale)
      values_by_locale.to_h do |locale, raw_value|
        [locale, stored_text(key, TypedValueParser.parse(raw_value, VALUE_DEFINITION).value)]
      end
    end

    # Rails renders the texts of keys ending in _html unescaped, so those are
    # cleaned like any other admin HTML before they are stored.
    def stored_text(key, value)
      if value.present? && html_text_key?(key)
        AdminWYSIWYGSanitizer.new.sanitize(value)
      else
        value
      end
    end

    def html_text_key?(key)
      key.end_with?("_html") || key.end_with?(".html")
    end

    # An empty value removes the override, so the bundled text shows again.
    def write_texts(parsed_texts)
      MachineTranslation.suppress do
        ActiveRecord::Base.transaction do
          parsed_texts.each do |key, values_by_locale|
            content = I18nContent.find_or_create_by!(key:)

            values_by_locale.each do |locale, value|
              Globalize.with_locale(locale) { content.update!(value: value.presence) }
            end
          end
        end
      end

      MachineTranslation::ChromeStore.reset!
    end
end
