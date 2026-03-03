class Adm::Ideas::IdeaPolicy < ApplicationPolicy
  def index?
    idea_manager_or_officer?
  end

  def show?
    idea_manager_or_officer?
  end

  def edit?
    idea_manager_or_officer?
  end

  def update?
    idea_manager_or_officer?
  end

  def destroy?
    idea_manager?
  end

  def audits?
    idea_manager_or_officer?
  end

  def accept?
    idea_manager?
  end

  def toggle_image?
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

    def idea_manager_or_officer?
      idea_manager? || @user&.idea_officer?
    end
end
