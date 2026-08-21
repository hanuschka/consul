class Projekts::Copying::BudgetCopier < ApplicationService
  EXCLUDED_BUDGET_COLUMNS = %w[projekt_id projekt_phase_id].freeze

  # Budget#generate_phases already built one phase per kind for the copy, with
  # its own next_phase chain; only the editable window and texts are taken over.
  EXCLUDED_PHASE_COLUMNS = %w[budget_id next_phase_id kind].freeze

  def initialize(nodes:, copy_phase:, record_copier:)
    @nodes = Array(nodes)
    @copy_phase = copy_phase
    @record_copier = record_copier
  end

  # ProjektPhase::BudgetPhase#create_budget already gave the copy a budget with
  # a default group and heading, so the first source budget takes it over
  # instead of landing beside it.
  def call
    return if nodes.empty?

    scaffolded_budgets = Budget.where(projekt_phase_id: copy_phase.id).order(:id).to_a

    nodes.each_with_index do |node, index|
      copy_budget(node, scaffolded_budgets[index])
    end
  end

  private

    attr_reader :nodes, :copy_phase, :record_copier

    def copy_budget(node, scaffolded_budget)
      copy = record_copier.overwrite_or_copy(
        node, scaffolded_budget,
        attributes: { projekt_phase_id: copy_phase.id, slug: nil },
        except: EXCLUDED_BUDGET_COLUMNS
      )

      record_copier.copy_images(node, copy)
      copy_group(node, copy)
      copy_budget_phases(node, copy)
    end

    def copy_group(node, copy_budget)
      group_node = node["group"]
      return if group_node.blank?

      group_copy = record_copier.overwrite_or_copy(
        group_node, copy_budget.group,
        attributes: { budget_id: copy_budget.id, slug: nil }
      )

      heading_node = node["heading"]
      return if heading_node.blank?

      record_copier.overwrite_or_copy(
        heading_node, group_copy.heading,
        attributes: { group_id: group_copy.id, slug: nil }
      )
    end

    def copy_budget_phases(node, copy_budget)
      pairs = matching_phase_pairs(node, copy_budget)

      apply_phase_dates(pairs)

      pairs.each do |phase_node, generated|
        record_copier.overwrite(phase_node, generated, except: EXCLUDED_PHASE_COLUMNS)
        record_copier.copy_images(phase_node, generated)
      end
    end

    def matching_phase_pairs(node, copy_budget)
      generated_phases = copy_budget.phases.index_by(&:kind)

      Array(node["phases"]).filter_map do |phase_node|
        generated = generated_phases[phase_node.dig("attributes", "kind")]
        next if generated.blank?

        [phase_node, generated]
      end
    end

    # Budget::Phase validates its window against the previous phase, and the
    # generated chain starts from today. Applying the source's dates one phase
    # at a time passes through orderings that do not validate, so they are
    # written first, as a set, without validation.
    def apply_phase_dates(pairs)
      pairs.each do |phase_node, generated|
        attributes = phase_node["attributes"] || {}

        generated.update_columns(
          starts_at: attributes["starts_at"],
          ends_at: attributes["ends_at"],
          enabled: attributes["enabled"]
        )
      end
    end
end
