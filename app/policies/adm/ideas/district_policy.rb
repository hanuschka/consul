class Adm::Ideas::DistrictPolicy < ApplicationPolicy
  include Adm::Ideas::Concerns::IdeaManageable

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
end
