class Adm::LandingPages::LandingPagePolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.landing_page_manager?
  end

  def new?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  def create?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  def edit?
    @user&.administrator? || @user&.landing_page_manager?(@record)
  end

  def update?
    @user&.administrator? || @user&.landing_page_manager?(@record)
  end

  def destroy?
    @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
  end

  class Scope < Scope
    def resolve
      pages = scope.landing

      if @user&.administrator? || @user&.landing_page_manager&.manage_all_landing_pages?
        pages
      elsif @user&.landing_page_manager?
        pages.where(id: @user.landing_page_manager.landing_page_manager_assignments.select(:page_id))
      else
        pages.none
      end
    end
  end
end
