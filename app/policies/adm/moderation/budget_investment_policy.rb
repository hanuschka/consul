class Adm::Moderation::BudgetInvestmentPolicy < ApplicationPolicy
  def index?
    can_moderate?
  end

  def hide?
    can_moderate?
  end

  def unhide?
    can_moderate? && @record.hidden?
  end

  def ignore_flag?
    can_moderate? && !@record.ignored_flag? && !@record.hidden?
  end

  class Scope < Scope
    def resolve
      scope.with_hidden
    end
  end
end
