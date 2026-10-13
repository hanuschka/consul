module MunicipalPlans
  class LegacyBackfill < ApplicationService
    Result = Struct.new(:rows_read, :outcomes, keyword_init: true)

    OUTCOMES = %i[
      procedure_step_set
      procedure_step_already_set
      procedure_step_not_in_export
      city_wide_set
      city_wide_already_set
      city_wide_has_districts
      working_copy_procedure_step_set
      working_copy_procedure_step_already_set
      working_copy_city_wide_set
      working_copy_city_wide_already_set
      working_copy_city_wide_has_districts
      untitled
      plan_not_found
    ].freeze

    LISTED_OUTCOMES = %i[
      procedure_step_not_in_export
      city_wide_has_districts
      working_copy_city_wide_has_districts
      plan_not_found
    ].freeze

    def initialize(file:)
      @file = file
      @outcomes = OUTCOMES.index_with { [] }
    end

    def call
      rows = LegacyImport.read(file)
      @procedure_steps = LegacyImport.procedure_steps(rows)

      MunicipalPlan.transaction do
        rows.each { |row| backfill(row) }
      end

      Result.new(rows_read: rows.size, outcomes: outcomes)
    end

    private

      attr_reader :file, :outcomes, :procedure_steps

      def backfill(row)
        legacy_id = LegacyImport.legacy_id(row)
        return record(:untitled, legacy_id) if LegacyImport.title(row).blank?

        plan = MunicipalPlan.find_by(legacy_id: legacy_id)
        return record(:plan_not_found, legacy_id) if plan.nil?

        step = LegacyImport.procedure_step(row, procedure_steps)
        city_wide, = LegacyImport.split_districts(row)
        record(:procedure_step_not_in_export, legacy_id) if step.nil? && procedure_steps.any?

        [plan, plan.working_copy].compact.each do |target|
          backfill_target(target, legacy_id, step, city_wide)
        end
      end

      def backfill_target(target, legacy_id, step, city_wide)
        prefix = target.working_copy? ? "working_copy_" : ""
        columns = {}

        if step
          outcome = target.procedure_step_id.nil? ? :set : :already_set
          columns[:procedure_step_id] = step.id if outcome == :set
          record(:"#{prefix}procedure_step_#{outcome}", legacy_id)
        end

        if city_wide
          outcome = city_wide_outcome(target)
          columns[:city_wide] = true if outcome == :set
          record(:"#{prefix}city_wide_#{outcome}", legacy_id)
        end

        target.update_columns(columns) if columns.any?
      end

      def city_wide_outcome(target)
        return :already_set if target.city_wide?
        return :has_districts if target.district_assignments.exists?

        :set
      end

      def record(outcome, legacy_id)
        outcomes.fetch(outcome) << legacy_id
      end
  end
end
