class Adm::Offers::OfferPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def update?
    index?
  end

  def edit?
    update?
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
