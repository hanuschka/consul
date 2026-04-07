class Adm::LandingPages::LandingPageManagerPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  def create?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  def destroy?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  def update?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
