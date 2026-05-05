class Adm::Projekts::BudgetPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def show?
    manage_permitted?
  end

  def edit?
    manage_permitted?
  end

  def update?
    manage_permitted?
  end

  def destroy?
    manage_permitted?
  end

  def hide?
    moderate_permitted?
  end

  def unhide?
    moderate_permitted? && @record.hidden?
  end

  def ignore_flag?
    moderate_permitted? && !@record.ignored_flag? && !@record.hidden?
  end

  def calculate_winners?
    manage_permitted? && @record.balloting_or_later?
  end

  def recalculate_winners?
    manage_permitted? && @record.balloting_or_later?
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
end
