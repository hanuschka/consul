class Adm::Projekts::BudgetPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end

  def edit?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
