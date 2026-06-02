module ProjektImports::ReferencesBuilder
  def self.build
    {
      "tags" => fetch_tags,
      "sdg_goals" => fetch_sdg_goals,
      "phase_types" => ProjektPhase::PROJEKT_PHASES_TYPES,
      "projekt_settings" => fetch_projekt_settings_defaults,
      "projekt_phase_settings" => fetch_phase_settings_defaults,
      "content_block_templates" => fetch_content_block_templates
    }
  end

  def self.fetch_tags
    Tag.pluck(:name).compact.uniq.first(200)
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] tags fetch failed: #{e.message}")
    []
  end

  def self.fetch_sdg_goals
    return [] unless defined?(SDG::Goal)

    SDG::Goal.all.map { |goal| { "code" => goal.code.to_s, "title" => goal.title } }
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] sdg fetch failed: #{e.message}")
    []
  end

  def self.fetch_projekt_settings_defaults
    ProjektSetting.defaults || {}
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] projekt settings fetch failed: #{e.message}")
    {}
  end

  def self.fetch_phase_settings_defaults
    defaults = ProjektPhaseSetting.defaults || {}
    defaults.transform_values { |settings| settings.transform_values(&:to_s) }
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] phase settings fetch failed: #{e.message}")
    {}
  end

  def self.fetch_content_block_templates
    response = DtApi::Client.new(use_cache: true).content_block_templates.all(section: "projekt_page")

    body = response.parsed_response
    Array(body.is_a?(Hash) ? body["content_block_templates"] : body)
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] content block templates fetch failed: #{e.message}")
    []
  end
end
