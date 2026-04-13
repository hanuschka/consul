class Adm::Valuation::BudgetInvestmentPolicy < ApplicationPolicy
  def index?
    valuator_or_admin?
  end

  def edit?
    update?
  end

  def update?
    valuator_or_admin? && assigned?
  end

  class Scope < Scope
    def resolve
      base = scope.joins(:budget).merge(active_budgets)

      if @user.administrator?
        base
      elsif @user.valuator?
        base.by_valuator(@user.valuator.id).visible_to_valuators
      else
        scope.none
      end
    end

    private

      def active_budgets
        Budget.joins(:phases, projekt_phase: :projekt).merge(Projekt.current)
              .where(budget_phases: { kind: %w[accepting reviewing selecting valuating], enabled: true })
              .distinct
      end
  end

  private

    def valuator_or_admin?
      @user&.valuator? || @user&.administrator?
    end

    def assigned?
      @user.administrator? ||
        Budget::ValuatorAssignment.exists?(investment_id: @record.id, valuator_id: @user.valuator.id)
    end
end
