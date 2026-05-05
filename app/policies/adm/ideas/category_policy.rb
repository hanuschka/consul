class Adm::Ideas::CategoryPolicy < ApplicationPolicy
  include Adm::Ideas::Concerns::IdeaManageable

  def index?
    idea_manager?
  end

  def new?
    idea_manager?
  end

  def create?
    idea_manager?
  end

  def edit?
    idea_manager?
  end

  def update?
    idea_manager?
  end

  def destroy?
    idea_manager?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
