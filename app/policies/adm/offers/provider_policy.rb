class Adm::Offers::ProviderPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.offer_manager?
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
      return scope.all if user&.administrator? || user&.offer_manager?

      scope.none
    end
  end
end
