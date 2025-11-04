class BudgetSerializer < BaseSerializer
  attr_reader :budget

  def initialize(budget)
    @budget = budget
  end

  def serialize
    budget_data = budget.as_json(
      only: [
        :id,
        :name,
        :phase,
        :currency_symbol,
        :voting_style,
        :published,
        :slug,
        :projekt_phase_id,
        :created_at,
        :updated_at
      ]
    )

    if budget.projekt_phase.present?
      budget_data[:projekt_phase] = {
        id: budget.projekt_phase.id,
        title: budget.projekt_phase.phase_tab_name,
        type: budget.projekt_phase.type,
        projekt_id: budget.projekt_phase.projekt_id
      }

      if budget.projekt_phase.projekt.present?
        projekt = budget.projekt_phase.projekt
        budget_data[:projekt] = {
          id: projekt.id,
          title: projekt.page&.title || projekt.name
        }
      end
    end

    if budget.respond_to?(:image) && budget.image.present? && budget.image.attached?
      budget_data[:image_url] = budget.image.url
    end

    budget_data
  end

  def self.serialize_collection(budgets)
    budgets.map { |budget| new(budget).serialize }
  end
end
