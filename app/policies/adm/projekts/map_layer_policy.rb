class Adm::Projekts::MapLayerPolicy < ApplicationPolicy
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

  private

  def projekt_from_record
    @record.mappable.is_a?(ProjektPhase) ? @record.mappable.projekt : @record.mappable
  end
end
