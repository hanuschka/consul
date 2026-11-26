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
    SDG::Goal.all.map { |goal| { "code" => goal.code.to_s, "title" => goal.title } }
  rescue NameError
    []
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] sdg fetch failed: #{e.message}")
    []
  end

  def self.fetch_projekt_settings_defaults
    defaults = ProjektSetting.defaults || {}
    allowed = ProjektImports::CreateProjektFromImportService::ALLOWED_PROJEKT_SETTINGS.map(&:to_sym)

    defaults.slice(*allowed)
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] projekt settings fetch failed: #{e.message}")
    {}
  end

  def self.fetch_phase_settings_defaults
    defaults = ProjektPhaseSetting.defaults || {}
    allowed_types = ProjektPhase::PROJEKT_PHASES_TYPES

    defaults
      .select { |phase_type, _settings| allowed_types.include?(phase_type.to_s) }
      .transform_values { |settings| settings.transform_values(&:to_s) }
  rescue StandardError => e
    Rails.logger.warn("[ProjektImports::ReferencesBuilder] phase settings fetch failed: #{e.message}")
    {}
  end

  # Hidden templates are dropped here rather than in the prompt alone, so the
  # resolver cannot render one either, even when the chat proposes its id.
  def self.fetch_content_block_templates
    templates_by_category = ContentBlockTemplates::Catalogue.call(section: "general")

    ContentBlockTemplates::Visibility
      .without_hidden_templates(templates_by_category)
      .flat_map do |category_data|
        category = {
          "category_id" => category_data.dig("category", "id"),
          "category_name" => category_data.dig("category", "name_en")
        }

        category_data["templates"].map { |template| template.merge(category) }
      end
  end
end
