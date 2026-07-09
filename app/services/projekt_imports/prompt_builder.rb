class ProjektImports::PromptBuilder
  attr_reader :base_prompt, :refs

  def initialize(base_prompt:, refs:, response_language: nil)
    @base_prompt = base_prompt
    @refs = refs
    @response_language = response_language.presence || default_response_language
  end

  def call
    <<~PROMPT
      #{base_prompt}

      Output response in #{response_language} language.

      #{build_templates_section}

      #{build_reference_data_section}

      #{build_projekt_settings_section}
      #{build_phase_settings_section}

      IMPORTANT: Never set "projekt_feature.main.activate" or "projekt_feature.general.show_in_navigation" to "active". Imported projekts must remain deactivated and hidden from navigation. Always set these to null.
    PROMPT
  end

  private

  def response_language
    @response_language
  end

  def default_response_language
    I18n.locale.to_s.start_with?("de") ? "German" : "English"
  end

  def build_reference_data_section
    lines = ["## Reference data", ""]

    tags = Array(refs["tags"]).compact
    if tags.present?
      lines << "Available categories: #{tags.map { |tag| %("#{tag}") }.join(', ')}"
    end

    goals = Array(refs["sdg_goals"])
    if goals.present?
      lines << "Available SDG goals: #{goals.map { |goal| "#{goal['code']} = #{goal['title']}" }.join(', ')}"
    end

    phase_types = Array(refs["phase_types"])
    if phase_types.present?
      lines << "Available phase types: #{phase_types.join(', ')}"
    end

    lines.join("\n")
  end

  def build_templates_section
    templates = refs["content_block_templates"] || []
    return "" if templates.blank?

    lines = []
    lines << "Available content block templates (ID — Name: Description):"

    templates.each do |t|
      desc = t["description"].presence ? ": #{t['description']}" : ""
      lines << "  #{t['id']} — #{t['name']}#{desc}"
    end

    lines.join("\n")
  end

  def build_projekt_settings_section
    settings = refs["projekt_settings"] || {}
    return "" if settings.blank?

    "Available projekt settings: #{settings.keys.join(', ')}"
  end

  def build_phase_settings_section
    phase_settings = refs["projekt_phase_settings"] || {}
    return "" if phase_settings.blank?

    sections = phase_settings.map do |phase_type, settings|
      "#{phase_type}: #{settings.keys.join(', ')}"
    end

    "Available phase settings per phase type:\n#{sections.join("\n")}"
  end
end
