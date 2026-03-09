class Adm::Projekts::LandingPagePolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  def update?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end

  class Scope < Scope
    def resolve
      scope.landing
    end
  end
end
