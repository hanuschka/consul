class BudgetPhases::BulkUpdateService < ApplicationService
  EDITABLE_ATTRIBUTES = %w[starts_at ends_at enabled].freeze

  def initialize(budget, phase_entries)
    @budget = budget
    @phase_entries = phase_entries
  end

  def call
    errors = []
    updated_phases = []

    Budget::Phase.transaction do
      @phase_entries.each do |phase_entry|
        phase = @budget.phases.find_by(kind: phase_entry[:kind])

        if phase.blank?
          errors << "Phase with kind '#{phase_entry[:kind]}' not found"
        else
          write_columns(phase, phase_entry)
          updated_phases << phase
        end
      end

      errors.concat(validation_errors(updated_phases))

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      ServiceResult.failure(error: errors)
    else
      ServiceResult.success(phases: updated_phases)
    end
  end

  private

    # Written without validation first: checked one at a time, moving several
    # phases together would trip over a neighbour that has not moved yet.
    def write_columns(phase, phase_entry)
      columns = phase_entry.to_h.slice(*EDITABLE_ATTRIBUTES)
      return if columns.empty?

      phase.update_columns(columns)
    end

    def validation_errors(phases)
      phases.flat_map do |phase|
        phase.reload

        if phase.valid?
          []
        else
          phase.errors.full_messages.map { |message| "#{phase.kind}: #{message}" }
        end
      end
    end
end
