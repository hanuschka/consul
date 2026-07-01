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
        :hide_money,
        :max_number_of_winners,
        :show_results_after_first_vote,
        :show_percentage_values_only,
        :max_preselected,
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

    if budget.respond_to?(:image) && budget.image.present?
      serialized_image = ImageSerializer.new(budget.image, include_variants: false).serialize
      budget_data[:image] = serialized_image if serialized_image.present?
    end

    if group_data.present?
      budget_data[:group] = group_data
    end

    budget_data
  end

  def group_data
    group = Budget::Group.find_by(budget_id: budget.id)

    return nil if group.nil?

    group_data = {
      id: group.id,
      name: group.name,
      slug: group.slug
    }

    if group.heading.present?
      heading = group.heading
      group_data[:heading] = {
        id: heading.id,
        name: heading.name,
        slug: heading.slug,
        price: heading.price,
        population: heading.population,
        max_ballot_lines: heading.max_ballot_lines
      }
    end

    group_data
  end

  def self.serialize_collection(budgets)
    budgets.map { |budget| new(budget).serialize }
  end
end
