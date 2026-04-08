class Adm::Ideas::DistrictPolicy < ApplicationPolicy
  def index?
    idea_manager?
  end

  def edit?
    idea_manager?
  end

  def update?
    idea_manager?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def idea_manager?
      @user&.administrator? || @user&.idea_manager?
    end
end
