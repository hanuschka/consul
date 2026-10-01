class Adm::MunicipalPlans::OfficerPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    index?
  end

  def create?
    index?
  end

  def update?
    index?
  end

  def destroy?
    index?
  end

  class Scope < Scope
    def resolve
      return scope.all if user&.administrator?

      scope.none
    end
  end
end
