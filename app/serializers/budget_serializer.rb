class BudgetSerializer < BaseSerializer
  TRANSLATED_ATTRIBUTES = %w[name main_link_text main_link_url].freeze

  PRELOADS = [
    :translations,
    { image: { attachment_attachment: :blob } },
    { group: [:translations, { heading: :translations }] },
    { projekt_phase: [:translations, { projekt: { page: :translations } }] }
  ].freeze

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

    budget_data.merge!(
      main_link_text: budget.main_link_text,
      main_link_url: budget.main_link_url,
      translations: serialize_translations(budget, TRANSLATED_ATTRIBUTES)
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

    if budget.image.present?
      serialized_image = ImageSerializer.new(budget.image, include_variants: false).serialize
      budget_data[:image] = serialized_image if serialized_image.present?
    end

    serialized_group = group_data

    if serialized_group.present?
      budget_data[:group] = serialized_group
    end

    budget_data
  end

  def group_data
    group = budget.group

    return nil if group.nil?

    group_data = {
      id: group.id,
      name: group.name,
      slug: group.slug,
      translations: serialize_translations(group, %w[name])
    }

    if group.heading.present?
      heading = group.heading
      group_data[:heading] = {
        id: heading.id,
        name: heading.name,
        slug: heading.slug,
        price: heading.price,
        population: heading.population,
        max_ballot_lines: heading.max_ballot_lines,
        translations: serialize_translations(heading, %w[name])
      }
    end

    group_data
  end

  def self.serialize_collection(budgets)
    budgets.map { |budget| new(budget).serialize }
  end
end
