class ProjektImports::PromptBuilder
  RESPONSE_LANGUAGE_LOCALES = {
    "German" => :de,
    "English" => :en
  }.freeze

  attr_reader :base_prompt, :refs

  def initialize(base_prompt:, refs:, response_language: nil)
    @base_prompt = base_prompt
    @refs = refs
    @response_language = response_language.presence || default_response_language
  end

  def call
    <<~PROMPT
      #{base_prompt}

      #{build_language_section}

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

  def response_locale
    RESPONSE_LANGUAGE_LOCALES.fetch(response_language, I18n.default_locale)
  end

  def phase_type_labels
    @phase_type_labels ||=
      I18n.with_locale(response_locale) { ProjektPhase.type_labels }
  end

  def build_language_section
    <<~SECTION
      ## Output language

      Every value you write that a citizen or administrator will read MUST be
      written in #{response_language}. This covers phase names, CTA button
      labels, phase and project descriptions, content block text, poll
      questions and answers, event, milestone and livestream titles, progress
      bar labels, argument texts, notification texts and point of interest
      category names.

      Field names, phase type identifiers and setting keys are part of the data
      format and stay exactly as given in English. Never copy a phase type
      identifier such as "ProjektPhase::VotingPhase", or an anglicised form of
      it like "Voting Phase", into a phase name — use the #{response_language}
      label listed for that type below.
    SECTION
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
      lines << "Available phase types (identifier — default #{response_language} name):"
      phase_types.each do |phase_type|
        lines << "  #{phase_type} — #{phase_type_labels[phase_type]}"
      end
      lines << "Use the default name as the phase name unless the document " \
               "states a different name for that phase."
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
