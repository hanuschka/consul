class ProjektEvaluations::UpdateVisibilityService < ApplicationService
  def initialize(projekt:, phase_params:)
    @projekt = projekt
    @phase_params = phase_params || {}
  end

  def call
    ActiveRecord::Base.transaction do
      update_phase_visibilities
    end
  end

  private

    attr_reader :projekt, :phase_params

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
