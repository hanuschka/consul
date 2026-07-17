class ProjektEvaluations::ToggleTabVisibilityService < ApplicationService
  TAB_SETTING_KEYS = {
    "stats" => "feature.general.public_kpi_stats",
    "ai" => "feature.general.public_ai_stats"
  }.freeze

  def initialize(projekt_phase:, tab:, visible:)
    @projekt_phase = projekt_phase
    @tab = tab.to_s
    @visible = ActiveModel::Type::Boolean.new.cast(visible) ? true : false
  end

  def call
    return false if TAB_SETTING_KEYS.keys.exclude?(@tab)

    if evaluation_completed?
      bulk_update_sections
    else
      update_phase_setting
    end
  end

  private

    def evaluation_completed?
      evaluation = @projekt_phase.projekt_phase_evaluation

      evaluation.present? && evaluation.completed?
    end

    def bulk_update_sections
      sections = tab_sections
      return false if sections.blank?

      record = @projekt_phase.projekt_phase_evaluation_visibility ||
        @projekt_phase.build_projekt_phase_evaluation_visibility
      changes = sections.index_with { @visible }.transform_keys { |key| "show_#{key}" }

      record.update!(changes)
    end

    def tab_sections
      available = ::PdfServices::EvaluationPdfSelection.available_sections(@projekt_phase.type)
      ai_sections = ::Adm::Projekts::EvaluationHelper::EVALUATION_AI_SECTIONS

      if @tab == "ai"
        available & ai_sections
      else
        available - ai_sections
      end
    end

    def update_phase_setting
      setting = @projekt_phase.settings.find_by(key: TAB_SETTING_KEYS[@tab])
      return false if setting.blank?

      setting.update!(value: @visible ? "active" : "")
    end
end
