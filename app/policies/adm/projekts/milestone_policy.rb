class Adm::Projekts::MilestonePolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def create?
    permitted?
  end

  def update?
    permitted?
  end

  def destroy?
    permitted?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.milestoneable&.respond_to?(:projekt) ? @record.milestoneable.projekt : @record.milestoneable
  end
end
