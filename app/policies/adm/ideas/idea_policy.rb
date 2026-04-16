class Adm::Ideas::IdeaPolicy < ApplicationPolicy
  include Adm::Ideas::Concerns::IdeaManageable

  def index?
    idea_manager_or_officer?
  end

  def show?
    idea_manager? || assigned_officer?
  end

  def edit?
    idea_manager? || assigned_officer?
  end

  def update?
    idea_manager? || assigned_officer?
  end

  def destroy?
    idea_manager?
  end

  def audits?
    idea_manager? || assigned_officer?
  end

  def accept?
    idea_manager?
  end

  def toggle_image?
    idea_manager?
  end

  def settings?
    idea_manager?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def idea_manager_or_officer?
      idea_manager? || @user&.idea_officer?
    end

    def assigned_officer?
      return false unless @user&.idea_officer?
      return false unless @record.is_a?(Idea)
      return true unless Setting["ideas.admins_must_assign_officer"].present?

      officer = @user.idea_officer
      return true if officer.manage_all?

      @record.officer == officer
    end
end
