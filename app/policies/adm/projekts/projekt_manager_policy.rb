class Adm::Projekts::ProjektManagerPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  def create?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  def destroy?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  def update?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
