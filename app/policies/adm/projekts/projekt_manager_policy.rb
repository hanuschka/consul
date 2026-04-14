class Adm::Projekts::ProjektManagerPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  def create?
    admin?
  end

  def destroy?
    admin?
  end

  def update?
    admin?
  end

  class Scope < Scope
    def resolve
      if @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
        scope.all
      else
        scope.none
      end
    end
  end

  private

    def admin?
      @user&.administrator?
    end
end
