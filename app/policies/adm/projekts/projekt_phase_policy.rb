class Adm::Projekts::ProjektPhasePolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    manage_permitted?
  end

  def show?
    manage_permitted?
  end

  def create?
    manage_permitted?
  end

  def update?
    manage_permitted?
  end

  def destroy?
    manage_permitted?
  end

  def moderate?
    manage_permitted? || moderate_permitted?
  end

  class Scope < Scope
    def resolve
      scope.where.not(type: "ProjektPhase::DebatePhase")
    end
  end

  private

  def projekt_from_record
    if @record.is_a?(Class)
      nil
    elsif @record.is_a?(Projekt)
      @record
    elsif @record.is_a?(ProjektPhase)
      @record.projekt
    else
      @record.projekt_phase&.projekt
    end
  end
end
