class Adm::Ideas::OfficerPolicy < ApplicationPolicy
  def index?
    idea_manager?
  end

  def search?
    idea_manager?
  end

  def create?
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

  private

    def idea_manager?
      @user&.administrator? || @user&.idea_manager?
    end
end
