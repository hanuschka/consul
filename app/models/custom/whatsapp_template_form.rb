class WhatsappTemplateForm
  include ActiveModel::Model

  NAME_PATTERN = /\A[a-z0-9_]+\z/.freeze
  LANGUAGE_PATTERN = /\A[a-z]{2}([_-][A-Za-z]{2})?\z/.freeze
  PLACEHOLDER_PATTERN = /\{\{\s*(\d+)\s*\}\}/.freeze
  LEADING_PLACEHOLDER_PATTERN = /\A\{\{\s*\d+\s*\}\}/.freeze
  TRAILING_PLACEHOLDER_PATTERN = /\{\{\s*\d+\s*\}\}\z/.freeze
  REQUIRED_PLACEHOLDERS = %w[1 2].freeze
  MAX_BODY_LENGTH = 1024

  attr_writer :name, :language
  attr_accessor :body

  validate :validate_name
  validate :validate_language
  validate :validate_body

  # 360dialog receives the parameterized name, so validating and re-rendering
  # that value keeps the field showing exactly what was submitted upstream.
  def name
    @name.to_s.strip.parameterize(separator: "_").presence
  end

  def language
    @language.to_s.strip.presence
  end

  private

    def validate_name
      if name.blank?
        errors.add(:name, I18n.t("adm.whatsapp.show.template_error_name_blank"))

        return
      end

      return if name.match?(NAME_PATTERN)

      errors.add(:name, I18n.t("adm.whatsapp.show.template_error_name_format"))
    end

    def validate_language
      if language.blank?
        errors.add(:language, I18n.t("adm.whatsapp.show.template_error_language_blank"))

        return
      end

      return if language.match?(LANGUAGE_PATTERN)

      errors.add(:language, I18n.t("adm.whatsapp.show.template_error_language_format"))
    end

    def validate_body
      if body.blank?
        errors.add(:body, I18n.t("adm.whatsapp.show.template_error_body_blank"))

        return
      end

      validate_body_length
      validate_body_placeholders
      validate_body_placeholder_edges
    end

    def validate_body_length
      return if body.length <= MAX_BODY_LENGTH

      errors.add(:body, I18n.t("adm.whatsapp.show.template_error_body_too_long",
        count: MAX_BODY_LENGTH))
    end

    def validate_body_placeholders
      placeholder_numbers = body.scan(PLACEHOLDER_PATTERN).flatten.uniq.sort

      return if placeholder_numbers == REQUIRED_PLACEHOLDERS

      errors.add(:body, I18n.t("adm.whatsapp.show.template_error_body_placeholders"))
    end

    # Meta rejects a body that starts or ends with a variable (error_subcode
    # 2388299), so both ends need static text around the placeholder.
    def validate_body_placeholder_edges
      text = body.strip

      return if !text.match?(LEADING_PLACEHOLDER_PATTERN) &&
        !text.match?(TRAILING_PLACEHOLDER_PATTERN)

      errors.add(:body, I18n.t("adm.whatsapp.show.template_error_body_placeholder_edges"))
    end
end
