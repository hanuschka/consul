class Projekts::Copying::BudgetCopier < ApplicationService
  EXCLUDED_BUDGET_COLUMNS = %w[projekt_id projekt_phase_id slug].freeze

  # Budget#generate_phases already built one phase per kind for the copy, with
  # its own next_phase chain; only the editable window and texts are taken over.
  EXCLUDED_PHASE_COLUMNS = %w[budget_id next_phase_id kind].freeze

  def initialize(source_phase:, copy_phase:, record_copier:)
    @source_phase = source_phase
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  # ProjektPhase::BudgetPhase#create_budget already gave the copy a budget with
  # a default group and heading, so the first source budget takes it over
  # instead of landing beside it.
  def call
    scaffolded_budgets = Budget.where(projekt_phase_id: copy_phase.id).order(:id).to_a

    Budget.where(projekt_phase_id: source_phase.id).order(:id).each_with_index do |budget, index|
      copy_budget(budget, scaffolded_budgets[index])
    end
  end

  private

    attr_reader :source_phase, :copy_phase, :record_copier

    def copy_budget(source_budget, scaffolded_budget)
      copy = record_copier.overwrite_or_copy(
        source_budget, scaffolded_budget,
        attributes: { projekt_phase_id: copy_phase.id, slug: nil },
        except: EXCLUDED_BUDGET_COLUMNS
      )

      record_copier.copy_images(source_budget, copy)
      copy_group(source_budget, copy)
      copy_budget_phases(source_budget, copy)
    end

    def copy_group(source_budget, copy_budget)
      source_group = source_budget.group
      return if source_group.blank?

      group_copy = record_copier.overwrite_or_copy(
        source_group, copy_budget.group,
        attributes: { budget_id: copy_budget.id, slug: nil }
      )

      source_heading = source_budget.heading
      return if source_heading.blank?

      record_copier.overwrite_or_copy(
        source_heading, group_copy.heading,
        attributes: { group_id: group_copy.id, slug: nil }
      )
    end

    def copy_budget_phases(source_budget, copy_budget)
      pairs = matching_phase_pairs(source_budget, copy_budget)

      apply_phase_dates(pairs)

      pairs.each do |source_budget_phase, generated|
        record_copier.overwrite(source_budget_phase, generated, except: EXCLUDED_PHASE_COLUMNS)
        record_copier.copy_images(source_budget_phase, generated)
      end
    end

    def matching_phase_pairs(source_budget, copy_budget)
      generated_phases = copy_budget.phases.index_by(&:kind)

      source_budget.phases.map do |source_budget_phase|
        generated = generated_phases[source_budget_phase.kind]
        next if generated.blank?

        [source_budget_phase, generated]
      end.compact
    end

    # Budget::Phase validates its window against the previous phase, and the
    # generated chain starts from today. Applying the source's dates one phase
    # at a time passes through orderings that do not validate, so they are
    # written first, as a set, without validation.
    def apply_phase_dates(pairs)
      pairs.each do |source_budget_phase, generated|
        generated.update_columns(
          starts_at: source_budget_phase.starts_at,
          ends_at: source_budget_phase.ends_at,
          enabled: source_budget_phase.enabled
        )
      end
    end
end
