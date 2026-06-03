class ProjektEvaluationVisibility < ApplicationRecord
  REPORT_SECTION_KEYS = %w[
    project_summary
    settings
    phase_summaries
  ].freeze

  REPORT_SECTION_COLUMNS = REPORT_SECTION_KEYS.map { |k| "show_#{k}" }.freeze

  belongs_to :projekt

  validates :projekt, presence: true
  validates :projekt_id, uniqueness: true

  def visible_sections
    REPORT_SECTION_KEYS.select { |key| self["show_#{key}"] }
  end

  def include_section?(key)
    return false if key.blank?
    return false if !REPORT_SECTION_KEYS.include?(key.to_s)

    self["show_#{key}"]
  end
end
