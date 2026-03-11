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
end
