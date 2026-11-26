# frozen_string_literal: true

module Schemas
  module Budgets
    PROJEKT_PHASE_REFERENCE_SCHEMA = {
      type: :object,
      description: 'Phase the budget belongs to',
      properties: {
        id: { type: :integer, example: 5 },
        title: { type: :string, nullable: true, example: 'Bürgerhaushalt' },
        type: { type: :string, example: 'ProjektPhase::BudgetPhase' },
        projekt_id: { type: :integer, example: 2 }
      }
    }.freeze

    PROJEKT_REFERENCE_SCHEMA = {
      type: :object,
      description: 'Projekt the budget belongs to',
      properties: {
        id: { type: :integer, example: 2 },
        title: { type: :string, nullable: true, example: 'Innenstadt 2030' }
      }
    }.freeze

    NAME_TRANSLATIONS = Schemas::Miscellaneous.translations_schema(%w[name])

    BUDGET_HEADING_SCHEMA = {
      type: :object,
      description: 'The heading of the budget: what the investments compete for',
      properties: {
        id: { type: :integer, example: 9 },
        name: { type: :string, description: 'Heading name in the current language', example: 'Gesamtes Stadtgebiet' },
        slug: { type: :string, nullable: true, example: 'gesamtes-stadtgebiet' },
        price: { type: :integer, nullable: true, description: 'Money available in the heading', example: 500000 },
        population: { type: :integer, nullable: true, example: 120000 },
        max_ballot_lines: { type: :integer, nullable: true, description: 'Investments a participant can choose', example: 3 },
        translations: NAME_TRANSLATIONS
      },
      additionalProperties: false
    }.freeze

    BUDGET_GROUP_SCHEMA = {
      type: :object,
      description: 'The group of the budget; every budget has exactly one group with one heading',
      properties: {
        id: { type: :integer, example: 8 },
        name: { type: :string, description: 'Group name in the current language', example: 'Stadtteile' },
        slug: { type: :string, nullable: true, example: 'stadtteile' },
        translations: NAME_TRANSLATIONS,
        heading: BUDGET_HEADING_SCHEMA
      },
      additionalProperties: false
    }.freeze

    BUDGET_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier for the budget', example: 1 },
        name: { type: :string, description: 'The name of the budget in the current language', example: 'Participatory Budget 2024' },
        slug: { type: :string, description: 'URL-friendly identifier for the budget', example: 'budget-2024' },
        phase: { type: :string, description: 'Stored phase kind of the budget', example: 'accepting' },
        main_link_text: { type: :string, nullable: true, description: 'Text of the budget\'s main link (current language)', example: 'Mehr erfahren' },
        main_link_url: { type: :string, nullable: true, description: 'URL of the budget\'s main link (current language). Required when main_link_text is set.', example: 'https://example.org/haushalt' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name main_link_text main_link_url]),
        currency_symbol: { type: :string, description: 'Currency symbol used (e.g., $, €, £, ¥)', example: '€' },
        voting_style: { type: :string, description: 'Voting mechanism: knapsack, approval or distributed', example: 'knapsack' },
        published: { type: :boolean, nullable: true, description: 'Whether the budget is publicly visible' },
        hide_money: { type: :boolean, nullable: true, description: 'Whether monetary values are hidden from public view' },
        max_number_of_winners: { type: :integer, nullable: true, description: 'Maximum number of winning proposals (0 = unlimited)', example: 0 },
        show_results_after_first_vote: { type: :boolean, nullable: true, description: 'Show voting results in real time' },
        show_percentage_values_only: { type: :boolean, nullable: true, description: 'Display only percentages instead of absolute values' },
        max_preselected: { type: :integer, nullable: true, description: 'Maximum pre-selected proposals (0 = disabled)', example: 0 },
        projekt_phase_id: { type: :integer, nullable: true, description: 'ID of the projekt phase this budget belongs to', example: 5 },
        projekt_phase: PROJEKT_PHASE_REFERENCE_SCHEMA,
        projekt: PROJEKT_REFERENCE_SCHEMA,
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        group: BUDGET_GROUP_SCHEMA,
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the budget was created', example: '2024-01-01T00:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the budget was last modified', example: '2024-01-15T10:00:00Z' }
      },
      required: %w[id name slug currency_symbol translations created_at updated_at],
      additionalProperties: false
    }.freeze

    BUDGET_WRITE_PROPERTIES = {
      name: { type: :string, description: 'Budget name (current language)' },
      main_link_text: { type: :string, nullable: true, description: 'Text of the main link (current language)' },
      main_link_url: { type: :string, nullable: true, description: 'URL of the main link (current language); required with main_link_text' },
      translations: Schemas::Miscellaneous.translations_schema(%w[name main_link_text main_link_url]),
      group_attributes: {
        type: :object,
        description: 'Name of the budget\'s group. Every budget has one group, so no id is needed.',
        properties: {
          name: { type: :string, description: 'Group name (current language)' },
          translations: NAME_TRANSLATIONS
        }
      }
    }.freeze

    BUDGET_PHASE_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, description: 'Unique identifier' },
        kind: { type: :string, description: 'Phase kind: informing, accepting, reviewing, selecting, valuating, publishing_prices, balloting, reviewing_ballots, finished' },
        name: { type: :string, description: 'Phase display name (current language)' },
        summary: { type: :string, nullable: true, description: 'Short summary of the phase (current language)' },
        description: { type: :string, nullable: true, description: 'Description of the phase (current language, max. 2000 characters)' },
        main_link_text: { type: :string, nullable: true, description: 'Text of the phase\'s main link (current language)' },
        main_link_url: { type: :string, nullable: true, description: 'URL of the phase\'s main link (current language)' },
        translations: Schemas::Miscellaneous.translations_schema(%w[name summary description main_link_text main_link_url]),
        starts_at: { type: :string, format: :date_time, nullable: true, description: 'Phase start date' },
        ends_at: { type: :string, format: :date_time, nullable: true, description: 'Phase end date' },
        enabled: { type: :boolean, description: 'Whether this phase is active' }
      },
      required: %w[id kind name enabled translations],
      additionalProperties: false
    }.freeze

    LABEL_SCHEMA = {
      type: :object,
      properties: {
        id: { type: :integer, example: 4 },
        name: { type: :string, nullable: true, example: 'Verkehr' },
        color: { type: :string, nullable: true, example: '#004a83' },
        icon: { type: :string, nullable: true, example: 'bus' }
      }
    }.freeze

    BUDGET_INVESTMENT_SCHEMA = {
      type: :object,
      description: 'A budget investment. Read-only clients get each value only where the public investment page shows it; the descriptions name the condition.',
      properties: {
        id: { type: :integer, description: 'Unique identifier for the budget investment', example: 1 },
        title: { type: :string, description: 'Title of the investment project (current language)', example: 'Park Renovation Project' },
        description: { type: :string, nullable: true, description: 'Description (current language)', example: 'Renovation and maintenance of Central Park' },
        translations: Schemas::Miscellaneous.translations_schema(%w[title description]),
        budget_id: { type: :integer, description: 'ID of the budget this investment belongs to', example: 10 },
        heading_id: { type: :integer, nullable: true, example: 9 },
        group_id: { type: :integer, nullable: true, example: 8 },
        **Schemas::Miscellaneous::EXTERNAL_REFERENCE_PROPERTIES,
        author_id: { type: :integer, nullable: true, description: 'ID of the user who proposed the investment. Only returned to admin clients.', example: 15 },
        author: { '$ref' => '#/components/schemas/Author' },
        on_behalf_of: { type: :string, nullable: true, description: 'Organisation the investment was submitted for; shown as the author name' },
        administrator_id: { type: :integer, nullable: true, description: 'ID of the administrator handling the investment. Only returned to admin clients.', example: 3 },
        administrator: {
          type: :object,
          nullable: true,
          description: 'Administrator handling the investment. Only returned to admin clients.',
          properties: {
            id: { type: :integer, description: 'Administrator ID' },
            name: { type: :string, nullable: true, description: 'Administrator name' }
          }
        },
        code: { type: :string, description: 'Internal reference code. Only returned to admin clients.', example: '2024-1-A3' },
        confidence_score: { type: :integer, description: 'Internal ranking score. Only returned to admin clients.' },
        visible_to_valuators: { type: :boolean, nullable: true, description: 'Only returned to admin clients.' },
        price: { type: :number, nullable: true, description: 'Estimated cost. Read-only clients: once prices are published for selected, feasible investments and the budget shows money.', example: 50000 },
        price_explanation: { type: :string, nullable: true, description: 'Explanation of the price. Same condition as price.' },
        price_first_year: { type: :number, nullable: true, description: 'Cost in the first year. Only returned to admin clients.' },
        duration: { type: :string, nullable: true, description: 'Expected duration. Only returned to admin clients.' },
        external_url: { type: :string, nullable: true, description: 'External link. Only returned to admin clients.' },
        location: { type: :string, nullable: true, description: 'Location as text. Only returned to admin clients.' },
        feasibility: { type: :string, nullable: true, enum: ['feasible', 'feasible_with_changes', 'unfeasible', 'undecided', nil], description: 'Feasibility assessment' },
        feasible: { type: :boolean, description: 'Meets the criteria, with or without changes by the administration.' },
        feasible_with_changes: { type: :boolean, description: 'Meets the criteria only with changes by the administration, described in valuator_explanation.' },
        unfeasible: { type: :boolean },
        undecided: { type: :boolean },
        valuation_finished: { type: :boolean, nullable: true },
        unfeasibility_explanation: { type: :string, nullable: true, description: 'Why the investment is unfeasible. Read-only clients: once the valuation finished as unfeasible.' },
        valuator_explanation: { type: :string, nullable: true, description: 'Explanation of the feasibility assessment as HTML. Read-only clients: where the public page shows it (price, unfeasibility, feasibility or changes explanation). Omitted when empty.', example: '<p>Does not meet the criteria.</p>' },
        selected: { type: :boolean, nullable: true, description: 'Selected for the ballot. Read-only clients see true only once the selection is public.' },
        preselected: { type: :boolean, nullable: true, description: 'Preselected by staff. Read-only. Read-only clients: from the valuating phase on.' },
        winner: { type: :boolean, nullable: true, description: 'Read-only clients: once the budget is finished and its results are public.' },
        incompatible: { type: :boolean, nullable: true, description: 'Same condition as winner.' },
        final_winner: { type: :boolean, description: 'Selected, winner and not incompatible. Same condition as winner.' },
        physical_votes: { type: :integer, nullable: true, description: 'Votes cast offline' },
        cached_votes_up: { type: :integer, nullable: true, description: 'Online supports' },
        total_votes: { type: :integer, description: 'Online supports plus physical votes' },
        ballot_lines_count: { type: :integer, nullable: true, description: 'Ballots containing the investment. Read-only clients: once ballots are counted and the phase shows the count.' },
        total_ballot_votes: { type: :integer, description: 'Weighted ballot votes. Same condition as ballot_lines_count.' },
        comments_count: { type: :integer, description: 'Visible comments' },
        implementation_performer: { type: :string, nullable: true, enum: ['city', 'user', nil], description: 'Who carries out the investment. Read-only clients: when the phase shows the implementation fields.' },
        implementation_contribution: { type: :string, nullable: true, description: 'What the submitter contributes. Same condition as implementation_performer.' },
        user_cost_estimate: { type: :string, nullable: true, description: 'Submitter\'s cost estimate. Read-only clients: when the phase shows it.' },
        sentiment_id: { type: :integer, nullable: true },
        sentiment: {
          type: :object,
          nullable: true,
          properties: {
            id: { type: :integer },
            name: { type: :string, nullable: true },
            color: { type: :string, nullable: true }
          }
        },
        projekt_labels: { type: :array, items: LABEL_SCHEMA },
        video_url: { type: :string, nullable: true },
        similar_contributions_count: { type: :integer, nullable: true, description: 'Number of other contributions in the same projekt with similar content. Determined freshly on every request and only when the "Pruefung auf aehnliche Beitraege" phase setting is enabled; 0 otherwise.', example: 2 },
        map_location: { '$ref' => '#/components/schemas/MapLocation' },
        heading: {
          type: :object,
          properties: { id: { type: :integer }, name: { type: :string, nullable: true } }
        },
        group: {
          type: :object,
          properties: { id: { type: :integer }, name: { type: :string, nullable: true } }
        },
        budget: { type: :object, description: 'The budget with its settings, phase, projekt and group' },
        projekt_phase: PROJEKT_PHASE_REFERENCE_SCHEMA,
        projekt: PROJEKT_REFERENCE_SCHEMA,
        image: { '$ref' => '#/components/schemas/ImageResponse' },
        documents: { type: :array, items: { '$ref' => '#/components/schemas/Document' } },
        tags: { type: :array, items: { type: :string } },
        created_at: { type: :string, format: :date_time, description: 'Timestamp when the investment was created', example: '2024-01-05T08:00:00Z' },
        updated_at: { type: :string, format: :date_time, description: 'Timestamp when the investment was last modified', example: '2024-01-18T14:30:00Z' }
      },
      required: %w[id title budget_id translations external_source external_id projekt_labels created_at updated_at],
      additionalProperties: false
    }.freeze

    # Fields added to the create and update bodies on top of the long-standing
    # ones documented inline in the request specs.
    BUDGET_INVESTMENT_WRITE_PROPERTIES = {
      translations: Schemas::Miscellaneous.translations_schema(%w[title description]),
      price_explanation: { type: :string, nullable: true, description: 'Explanation of the price' },
      price_first_year: { type: :number, nullable: true, description: 'Cost in the first year' },
      duration: { type: :string, nullable: true, description: 'Expected duration' },
      unfeasibility_explanation: { type: :string, nullable: true, description: 'Why the investment is unfeasible' },
      external_url: { type: :string, nullable: true, description: 'External link' },
      location: { type: :string, nullable: true, description: 'Location as text' },
      implementation_performer: { type: :string, nullable: true, enum: %w[city user], description: 'Who carries out the investment' },
      implementation_contribution: { type: :string, nullable: true, description: 'What the submitter contributes' },
      user_cost_estimate: { type: :string, nullable: true, description: 'Submitter\'s cost estimate' },
      sentiment_id: { type: :integer, nullable: true, description: 'Sentiment of the phase (GET /api/projekt_phases/{id}/sentiments)' },
      projekt_label_ids: { type: :array, items: { type: :integer }, description: 'Labels of the phase (GET /api/projekt_phases/{id}/projekt_labels)' },
      physical_votes: { type: :integer, nullable: true, description: 'Votes cast offline; they count into total_votes and the ranking' },
      winner: { type: :boolean, nullable: true, description: 'Mark as winner. Applied after incompatible, so it survives the heading\'s winner recalculation when both are sent.' },
      incompatible: { type: :boolean, nullable: true, description: 'Mark as incompatible. Changing it recalculates every winner of the heading, like in /adm.' },
      map_location_attributes: { '$ref' => '#/components/schemas/MapLocationWriteParams' }
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
