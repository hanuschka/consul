class Adm::Projekts::ProjektPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

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
      scope.includes([:projekt_settings, :parent, [page: :translations]])
    end
  end
end
