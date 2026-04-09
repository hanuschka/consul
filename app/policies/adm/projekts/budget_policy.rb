class Adm::Projekts::BudgetPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def show?
    permitted?
  end

  def edit?
    permitted?
  end

  def update?
    permitted?
  end

  def destroy?
    permitted?
  end

  def hide?
    can_moderate_projekt?
  end

  def unhide?
    can_moderate_projekt? && @record.hidden?
  end

  def ignore_flag?
    can_moderate_projekt? && !@record.ignored_flag? && !@record.hidden?
  end

  def calculate_winners?
    permitted? && @record.balloting_or_later?
  end

  def recalculate_winners?
    permitted? && @record.balloting_or_later?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.respond_to?(:projekt) ? @record.projekt : @record.budget&.projekt
  end

  def can_moderate_projekt?
    @user&.has_pm_permission_to?("moderate", projekt_from_record)
  end
end
