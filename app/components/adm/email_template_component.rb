class Adm::EmailTemplateComponent < ApplicationComponent
  PLACEHOLDER_START = "\u{E000}".freeze
  PLACEHOLDER_END = "\u{E001}".freeze
  PLACEHOLDER_PATTERN = /#{PLACEHOLDER_START}([^#{PLACEHOLDER_END}]*)#{PLACEHOLDER_END}/

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
      source.gsub(/<%=\s*(?:(?!%>).)*?t\("([^"]+)"(?:(?!%>).)*%>/) do
        tag = Regexp.last_match(0)
        key = Regexp.last_match(1)
        translation = I18n.t(key, default: nil, **default_interpolations(key))
        next placeholder(key) if translation.nil?

        url_expression = translated_link_target(tag, key)
        url_expression ? link_preview(translation, summarize_erb(url_expression)) : translation
      end
      # Replace remaining ERB output tags with bracketed placeholders
      .gsub(/<%=\s*(.+?)\s*%>/) { placeholder(summarize_erb($1)) }
      # Remove non-output ERB tags (logic)
      .gsub(/<%[^=].*?%>/m, "")
    end

    def default_interpolations(key)
      # Provide placeholder values for common interpolation keys
      translation_source = I18n.t(key, default: "")
      placeholders = translation_source.scan(/%\{(\w+)\}/).flatten
      placeholders.to_h { |p| [p.to_sym, placeholder(p)] }
    end

    def placeholder(name)
      "#{PLACEHOLDER_START}#{name}#{PLACEHOLDER_END}"
    end

    def variable_for(name)
      @email_template.preview_aliases[name] || (name if variables.include?(name))
    end

    def link_preview(text, name)
      variable = variable_for(name)
      variable ? "#{text} ({{ #{variable} }})" : text
    end

    def translated_link_target(tag, key)
      code = tag.sub(/\A<%=/, "").sub(/%>\z/, "")
      match = code.match(/link_to\s*\(?\s*(?=t\("#{Regexp.escape(key)}")/)
      return if match.nil?

      rest = code[match.end(0)..]
      text_argument = first_argument(rest)
      after_text = rest[text_argument.length..]
      return unless after_text.match?(/\A\s*,/)

      url_expression = first_argument(after_text.sub(/\A\s*,/, "")).strip
      url_expression.presence
    end

    def first_argument(code)
      depth = 0
      quote = nil

      code.each_char.with_index do |char, index|
        if quote
          quote = nil if char == quote
        elsif char == '"' || char == "'"
          quote = char
        elsif "([{".include?(char)
          depth += 1
        elsif ")]}".include?(char)
          return code[0...index] if depth.zero?

          depth -= 1
        elsif char == "," && depth.zero?
          return code[0...index]
        end
      end

      code
    end

    def resolve_placeholders(html)
      html.gsub(/<a\b[^>]*?\bhref=(["']?)(?:mailto:)?#{PLACEHOLDER_PATTERN}\1(?=[\s>])[^>]*>(.*?)<\/a>/m) do
        link_preview(Regexp.last_match(3).strip, Regexp.last_match(2))
      end
      .gsub(PLACEHOLDER_PATTERN) do
        variable = variable_for(Regexp.last_match(1))
        variable ? "{{ #{variable} }}" : "\u2026"
      end
    end

    def summarize_erb(expression)
      # Extract meaningful name from common patterns
      case expression
      when /\.recipient_greeting\z/ then "recipient_greeting"
      when /\A@(\w+)\z/ then $1
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
      html = resolve_placeholders(html)
      # Allow basic structural tags only
      helpers.sanitize(html, tags: %w[p h1 h2 h3 br strong em a div span td tr table ul ol li], attributes: %w[href])
    end
end
