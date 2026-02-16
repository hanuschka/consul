class Adm::Projekts::FormularFieldPolicy < ApplicationPolicy
  def create?
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
