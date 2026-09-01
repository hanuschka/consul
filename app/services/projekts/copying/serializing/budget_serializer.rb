class Projekts::Copying::Serializing::BudgetSerializer < ApplicationService
  EXCLUDED_SLUG_COLUMNS = %w[slug].freeze

  def initialize(source_phase:)
    @source_phase = source_phase
  end

  def call
    Budget.where(projekt_phase_id: source_phase.id).order(:id).map do |budget|
      budget_node(budget)
    end
  end

  private

    attr_reader :source_phase

    def budget_node(budget)
      node = Projekts::Copying::Serializing::RecordSerializer.call(
        budget, except: EXCLUDED_SLUG_COLUMNS
      )

      node
        .merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: budget))
        .merge(
          "group" => group_node(budget),
          "heading" => heading_node(budget),
          "phases" => budget.phases.map { |budget_phase| budget_phase_node(budget_phase) }
        )
    end

    def group_node(budget)
      group = budget.group
      return nil if group.blank?

      Projekts::Copying::Serializing::RecordSerializer.call(
        group, except: EXCLUDED_SLUG_COLUMNS
      )
    end

    def heading_node(budget)
      heading = budget.heading
      return nil if heading.blank?

      Projekts::Copying::Serializing::RecordSerializer.call(
        heading, except: EXCLUDED_SLUG_COLUMNS
      )
    end

    # Budget#generate_phases builds one phase per kind for the copy with its own
    # next_phase chain, so `kind` is what pairs a source phase with a generated
    # one and only the window and the texts are taken over.
    def budget_phase_node(budget_phase)
      node = Projekts::Copying::Serializing::RecordSerializer.call(budget_phase)

      node.merge(Projekts::Copying::Serializing::AttachableSerializer.call(record: budget_phase))
    end
end
