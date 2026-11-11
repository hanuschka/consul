# The email templates that belong to no projekt phase: the global ones and the
# deficiency-report ones. Each language is its own row; a template without a
# customized subject or body sends the built-in email.
class Api::Configuration::EmailTemplatesController < Api::Configuration::BaseController
  KEY_SEPARATOR = ".".freeze

  SECTIONS = {
    "global" => SiteCustomization::EmailTemplate::GLOBAL_EMAIL_TEMPLATES,
    "deficiency_reports" => SiteCustomization::EmailTemplate::DEFICIENCY_REPORT_EMAIL_TEMPLATES
  }.freeze

  ATTRIBUTE_DEFINITIONS = {
    "subject" => TypedValueParser::Definition.new(type: :string, allow_blank: true),
    "body" => TypedValueParser::Definition.new(type: :text, allow_blank: true)
  }.freeze

  before_action :find_mailer, only: [:show, :update]

  def index
    templates_by_key = phaseless_templates.group_by(&:template_key)

    email_templates = SECTIONS.flat_map do |section, mailers|
      mailers.map do |mailer_class, mailer_action|
        serialize(section, mailer_class, mailer_action, templates_by_key["#{mailer_class}##{mailer_action}"])
      end
    end

    render json: { data: { email_templates: } }
  end

  def show
    render json: { data: { email_template: serialize_current } }
  end

  def update
    translations_param = params.dig(:email_template, :translations)
    translations = permitted_translations(translations_param, ATTRIBUTE_DEFINITIONS.keys)
    errors = unsupported_locales_error(translations_param) || translation_errors(translations)

    if errors.present?
      render_invalid_values(errors)
    elsif translations.empty?
      raise ActionController::ParameterMissing, :translations
    else
      write_translations(translations)

      render json: { data: { email_template: serialize_current } }
    end
  rescue ActiveRecord::RecordInvalid => error
    render_record_errors(error.record)
  end

  private

    def find_mailer
      @section, (@mailer_class, @mailer_action) = mailers_by_key[params[:key].to_s]

      if @section.nil?
        raise ActiveRecord::RecordNotFound
      end
    end

    # Keys are lower case ("mailer.comment",
    # "deficiency_report_mailer.notify_officer"): GET paths with capitals are
    # redirected to their lower-case form.
    def template_api_key(mailer_class, mailer_action)
      "#{mailer_class.underscore}#{KEY_SEPARATOR}#{mailer_action}"
    end

    def mailers_by_key
      SECTIONS.each_with_object({}) do |(section, mailers), mailers_by_key|
        mailers.each { |mailer| mailers_by_key[template_api_key(*mailer)] = [section, mailer] }
      end
    end

    def phaseless_templates
      SiteCustomization::EmailTemplate.where(projekt_phase_id: nil)
    end

    def current_templates
      phaseless_templates.where(mailer_class: @mailer_class, mailer_action: @mailer_action)
    end

    def serialize_current
      serialize(@section, @mailer_class, @mailer_action, current_templates.to_a)
    end

    def serialize(section, mailer_class, mailer_action, templates)
      templates_by_locale = Array(templates).index_by { |template| template.locale.to_s }
      registry_entry =
        SiteCustomization::EmailTemplate::EMAIL_TEMPLATES.fetch("#{mailer_class}##{mailer_action}", {})

      {
        key: template_api_key(mailer_class, mailer_action),
        mailer_class:,
        mailer_action:,
        section:,
        variables: registry_entry.fetch(:variables, []),
        translations: available_locales.index_with do |locale|
          template = templates_by_locale[locale]

          {
            subject: template&.subject,
            body: template&.body,
            updated_at: template&.updated_at
          }
        end
      }
    end

    def translation_errors(translations)
      errors = {}

      translations.each do |locale, attributes|
        attributes.each do |attribute_name, raw_value|
          message = attribute_error(attribute_name, raw_value)

          if message
            errors["#{locale}.#{attribute_name}"] = [message]
          end
        end
      end

      errors.presence
    end

    def attribute_error(attribute_name, raw_value)
      result = TypedValueParser.parse(raw_value, ATTRIBUTE_DEFINITIONS.fetch(attribute_name))

      if !result.valid?
        result.error
      elsif result.value.present?
        liquid_error(result.value)
      end
    end

    def liquid_error(template_text)
      Liquid::Template.parse(template_text)

      nil
    rescue Liquid::Error => error
      "is not a valid template: #{error.message}"
    end

    # Subject and body are stored as given, like /adm stores them; the email
    # view sanitizes the rendered body.
    def write_translations(translations)
      ActiveRecord::Base.transaction do
        translations.each do |locale, attributes|
          template = current_templates.find_or_initialize_by(locale:)

          attributes.each do |attribute_name, raw_value|
            template[attribute_name] = TypedValueParser
              .parse(raw_value, ATTRIBUTE_DEFINITIONS.fetch(attribute_name))
              .value
              .presence
          end

          template.save!
        end
      end
    end
end
