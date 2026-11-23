class Adm::OfferManagerPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def create?
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
