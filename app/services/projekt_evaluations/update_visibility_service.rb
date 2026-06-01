class ProjektEvaluations::UpdateVisibilityService < ApplicationService
  def initialize(projekt:, report_params:, phase_params:)
    @projekt = projekt
    @report_params = report_params || {}
    @phase_params = phase_params || {}
  end

  def call
    ActiveRecord::Base.transaction do
      update_report_visibility
      update_phase_visibilities
    end
  end

  private

    attr_reader :projekt, :report_params, :phase_params

    def update_report_visibility
      return if report_params.blank?

      record = projekt.projekt_evaluation_visibility ||
        projekt.build_projekt_evaluation_visibility

      record.update!(report_attrs)
    end

    def report_attrs
      ProjektEvaluationVisibility::REPORT_SECTION_COLUMNS.each_with_object({}) do |col, memo|
        memo[col] = boolean_value(report_params[col])
      end
    end

    def update_phase_visibilities
      projekt.projekt_phases.each do |phase|
        phase_attrs = phase_params[phase.id.to_s] || {}

        record = phase.projekt_phase_evaluation_visibility ||
          phase.build_projekt_phase_evaluation_visibility

        record.update!(phase_section_attrs(phase_attrs))
      end
    end

    def phase_section_attrs(attrs)
      ProjektPhaseEvaluationVisibility::SECTION_COLUMNS.each_with_object({}) do |col, memo|
        memo[col] = boolean_value(attrs[col])
      end
    end

    def boolean_value(value)
      ActiveModel::Type::Boolean.new.cast(value) ? true : false
    end
end
