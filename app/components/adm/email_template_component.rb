class Adm::EmailTemplateComponent < ApplicationComponent
  delegate :ck_editor_class, to: :helpers

  def initialize(email_template, open: false, recipient_type: nil)
    @email_template = email_template
    @open = open
    @recipient_type = recipient_type
  end

  def recipient_type_label
    return nil if @recipient_type.blank?

    I18n.t("components.adm.email_template_component.recipient_types.#{@recipient_type}", default: nil)
  end

  def recipient_type_icon
    case @recipient_type.to_s
    when "subscribers" then "group"
    else "person"
    end
  end

  def label
    I18n.t("#{@email_template.mailer_class.underscore}.#{@email_template.mailer_action}.title")
  end

  def description
    key = "#{@email_template.mailer_class.underscore}.#{@email_template.mailer_action}.description"

    helpers.sanitize(
      I18n.t(key, **description_interpolations),
      tags: %w[a],
      attributes: %w[href data-turbo-frame]
    )
  end

  def recipient
    I18n.t("#{@email_template.mailer_class.underscore}.#{@email_template.mailer_action}.recipient", default: nil)
  end

  def variables
    @email_template.registered_variables
  end

  def variables_hint
    variables.map { |v| "{{ #{v} }}" }.join("<br>")
  end

  def path
    helpers.adm_email_template_path(@email_template)
  end

  def send_test_path
    helpers.send_test_adm_email_template_path(@email_template)
  end

  def sanitized_body
    AdminWYSIWYGSanitizer.new.sanitize(@email_template.body)
  end

  def default_template_preview
    source = default_template_source
    return nil if source.blank?

    html = resolve_erb_tags(source)
    sanitize_preview(html)
  end

  private

    def description_interpolations
      return {} unless @email_template.deficiency_report_template?

      {
        settings_link: helpers.link_to(
          I18n.t("components.adm.email_template_component.settings_link_text"),
          helpers.adm_deficiency_reports_settings_path,
          data: { turbo_frame: "_top" }
        )
      }
    end

    def default_template_source
      view_dir = @email_template.mailer_class.underscore
      action = @email_template.mailer_action
      custom_path = Rails.root.join("app/views/custom/#{view_dir}/#{action}.html.erb")
      base_path = Rails.root.join("app/views/#{view_dir}/#{action}.html.erb")

      path = custom_path.exist? ? custom_path : base_path
      path.exist? ? path.read : nil
    end

    def resolve_erb_tags(source)
      # First, collapse multi-line ERB tags into single lines
      source = source.gsub(/<%=.*?%>/m) { |match| match.gsub(/\s+/, " ") }

      # Resolve any ERB tag containing a t() call — handles sanitize(t(...)), link_to(t(...)), etc.
      source.gsub(/<%=\s*[^%]*t\("([^"]+)"[^%]*%>/) do
        key = $1
        translation = I18n.t(key, default: nil, **default_interpolations(key))
        translation || "[#{key}]"
      end
      # Replace remaining ERB output tags with bracketed placeholders
      .gsub(/<%=\s*(.+?)\s*%>/) { "[#{summarize_erb($1)}]" }
      # Remove non-output ERB tags (logic)
      .gsub(/<%[^=].*?%>/m, "")
    end

    def default_interpolations(key)
      # Provide placeholder values for common interpolation keys
      translation_source = I18n.t(key, default: "")
      placeholders = translation_source.scan(/%\{(\w+)\}/).flatten
      placeholders.to_h { |p| [p.to_sym, "[#{p}]"] }
    end

    def summarize_erb(expression)
      # Extract meaningful name from common patterns
      case expression
      when /@(\w+)\.(\w+)/  then $2
      when /link_to.*?,\s*(\w+)/ then "link"
      when /(\w+_url|_path)/ then $1
      else expression.truncate(30)
      end
    end

    def sanitize_preview(html)
      # Strip style attributes, keep structure
      html = html.gsub(/\s*style="[^"]*"/, "")
      # Strip css helper calls
      html = html.gsub(/\s*style="<%= css_for_\w+ %>"/, "")
      # Allow basic structural tags only
      helpers.sanitize(html, tags: %w[p h1 h2 h3 br strong em a div span td tr table ul ol li], attributes: %w[href])
    end
end
