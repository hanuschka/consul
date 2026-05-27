class ProjektImports::Builders::BudgetBuilder < ProjektImports::Builders::Base
  BUDGET_PHASE_KINDS = %w[
    informing accepting reviewing selecting valuating
    publishing_prices balloting reviewing_ballots finished
  ].freeze

  def call
    return nil if payload.blank?

    budget = build_budget
    configure_phases(budget)
    budget
  rescue ActiveRecord::RecordInvalid => e
    raise ProjektImports::Builders::BuilderError, "budget: #{e.message}"
  end

  private

  def build_budget
    budget = projekt.budgets.create!(
      name: phase.name.presence || projekt.name,
      slug: budget_slug,
      currency_symbol: payload["currency_symbol"].presence || "€",
      voting_style: payload["voting_style"].presence || "knapsack",
      hide_money: ActiveModel::Type::Boolean.new.cast(payload["hide_money"]),
      phase: "informing"
    )

    if payload["total_amount"].present? && budget.respond_to?(:total_amount=)
      budget.update!(total_amount: payload["total_amount"])
    end

    budget
  end

  def configure_phases(budget)
    raw_phases = Array(payload["phases"]).index_by { |ph| ph["kind"] }

    BUDGET_PHASE_KINDS.each do |kind|
      phase_data = raw_phases[kind]
      next if phase_data.blank?

      record = budget.phases.find_by(kind: kind)
      next if record.blank?

      record.update!(
        enabled: ActiveModel::Type::Boolean.new.cast(phase_data["enabled"]),
        starts_at: phase_data["starts_at"].presence,
        ends_at: phase_data["ends_at"].presence
      )
    end
  end

  def budget_slug
    base = "#{projekt.name}-budget".parameterize
    "#{base}-#{SecureRandom.hex(3)}"
  end
end
