# frozen_string_literal: true

module Schemas
  module Budgets
    BUDGET_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the budget', example: 1 },
        name: { type: :string, description: 'The name of the budget phase', example: 'Participatory Budget 2024' },
        slug: { type: :string, description: 'URL-friendly identifier for the budget', example: 'budget-2024' },
        description: { type: :string, nullable: true, description: 'Description of the budget and its objectives', example: 'Public funding allocation for community projects' },
        currency_symbol: { type: :string, description: 'Currency symbol used (e.g., $, €, £, ¥)', example: '€' },
        voting_style: { type: :string, description: 'Voting mechanism: knapsack, approval or distributed', example: 'knapsack' },
        published: { type: :boolean, description: 'Whether the budget is publicly visible' },
        hide_money: { type: :boolean, description: 'Whether monetary values are hidden from public view' },
        max_number_of_winners: { type: :integer, description: 'Maximum number of winning proposals (0 = unlimited)', example: 0 },
        show_results_after_first_vote: { type: :boolean, description: 'Show voting results in real time' },
        show_percentage_values_only: { type: :boolean, description: 'Display only percentages instead of absolute values' },
        max_preselected: { type: :integer, description: 'Maximum pre-selected proposals (0 = disabled)', example: 0 },
        projekt_phase_id: { type: :integer, description: 'ID of the projekt phase this budget belongs to', example: 5 },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the budget was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the budget was last modified', example: '2024-01-15T10:00:00Z' }
      },
      required: %w[id name slug currency_symbol projekt_phase_id created_at updated_at]
    }.freeze

    BUDGET_PHASE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier' },
        kind: { type: :string, description: 'Phase kind: informing, accepting, reviewing, selecting, valuating, publishing_prices, balloting, reviewing_ballots, finished' },
        name: { type: :string, description: 'Phase display name' },
        starts_at: { type: :string, format: :date_time, nullable: true, description: 'Phase start date' },
        ends_at: { type: :string, format: :date_time, nullable: true, description: 'Phase end date' },
        enabled: { type: :boolean, description: 'Whether this phase is active' }
      },
      required: %w[id kind name enabled]
    }.freeze

    BUDGET_INVESTMENT_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the budget investment', example: 1 },
        title: { type: :string, description: 'Title of the investment project', example: 'Park Renovation Project' },
        description: { type: :string, nullable: true, description: 'Detailed description of what the investment will fund', example: 'Renovation and maintenance of Central Park' },
        budget_id: { type: :integer, description: 'ID of the budget this investment belongs to', example: 10 },
        author_id: { type: :integer, nullable: true, description: 'ID of the user who proposed the investment', example: 15 },
        price: { type: :number, nullable: true, description: 'Estimated cost or budget amount for this investment', example: 50000 },
        status: { type: :string, nullable: true, description: 'Status of the investment (e.g., selected, unselected, feasible)', example: 'selected' },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the investment was created', example: '2024-01-05T08:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the investment was last modified', example: '2024-01-18T14:30:00Z' },
        similar_contributions_count: { type: :integer, nullable: true, description: 'Number of other contributions in the same projekt with similar content. Determined freshly on every request and only when the "Pruefung auf aehnliche Beitraege" phase setting is enabled; 0 otherwise.', example: 2 },
        image: { '$ref' => '#/components/schemas/ImageResponse' }
      },
      required: %w[id title budget_id created_at updated_at]
    }.freeze

    def self.all
      {
        Budget: BUDGET_SCHEMA,
        BudgetPhase: BUDGET_PHASE_SCHEMA,
        BudgetInvestment: BUDGET_INVESTMENT_SCHEMA
      }
    end
  end
end
