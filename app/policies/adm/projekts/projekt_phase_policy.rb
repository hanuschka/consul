class Adm::Projekts::ProjektPhasePolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    permitted?
  end

  def show?
    permitted?
  end

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
      scope.where.not(type: "ProjektPhase::DebatePhase")
    end
  end

  private

  def projekt_from_record
    @record.is_a?(ProjektPhase) ? @record.projekt : @record.projekt_phase&.projekt
  end
end
