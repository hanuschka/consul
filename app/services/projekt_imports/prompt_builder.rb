class ProjektImports::PromptBuilder
  RESPONSE_LANGUAGE_LOCALES = {
    "German" => :de,
    "English" => :en
  }.freeze

  attr_reader :base_prompt, :refs, :source_images

  def initialize(base_prompt:, refs:, response_language: nil, source_images: [])
    @base_prompt = base_prompt
    @refs = refs
    @response_language = response_language.presence || default_response_language
    @source_images = Array(source_images)
  end

  def call
    <<~PROMPT
      #{base_prompt}

      #{build_language_section}

      #{build_templates_section}

      #{build_source_images_section}

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
      marker = image_template?(t) ? " [has #{image_slot_count(t)} image slot(s)]" : ""
      lines << "  #{t['id']} — #{t['name']}#{desc}#{marker}"
    end

    lines.join("\n")
  end

  # The images embedded in the uploaded document are extracted before this call
  # so that the templates chosen here can hold them. Selecting only text
  # templates silently throws every photo in the document away, which is why the
  # instruction is phrased as a requirement and repeats the count.
  #
  # No URLs are given: the model never sees them and never writes an <img src>.
  # The slots are filled from the stored images afterwards, so a wrong or
  # invented URL is not a failure mode that exists.
  def build_source_images_section
    return "" if source_images.blank?

    <<~SECTION.strip
      ## Images from the uploaded document

      The uploaded document#{'s' if source_files_count > 1} contain #{source_images.size} usable
      #{'image'.pluralize(source_images.size)}, listed here in the order they appear:
      #{source_image_lines}

      The first suitable one becomes the project's title image. You MUST choose
      content block templates whose image slots together can hold the remaining
      #{[source_images.size - 1, 0].max}, using the "[has N image slot(s)]" marker above to
      find them — a gallery template for several images, an image-and-text
      template for one. Place each such block where the document discusses what
      the image shows. Never write an image URL or filename into content_data:
      the slots are filled in automatically after you answer.
    SECTION
  end

  def source_image_lines
    source_images.each_with_index.map { |image, index|
      "  #{index + 1}. #{image['width']}x#{image['height']} px (#{orientation_of(image)})"
    }.join("\n")
  end

  def orientation_of(image)
    width = image["width"].to_i
    height = image["height"].to_i

    return "portrait" if height > width * 1.2
    return "landscape" if width > height * 1.2

    "square"
  end

  def source_files_count
    source_images.map { |image| image["source_filename"] }.uniq.size
  end

  def image_template?(template)
    image_slot_count(template).positive?
  end

  # Counted by the filler's own rule rather than by grepping for <img>, so a hero
  # or overlay template that carries its picture as a background-image is offered
  # to the model instead of being marked as having no room for one.
  def image_slot_count(template)
    HtmlImageSlots.count(template["content"] || template["html"])
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
