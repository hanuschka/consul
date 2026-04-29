class Adm::Projekts::MapLayerPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def create?
    manage_permitted?
  end

  def update?
    manage_permitted?
  end

  def destroy?
    manage_permitted?
  end

  private

  def projekt_from_record
    @record.mappable.is_a?(ProjektPhase) ? @record.mappable.projekt : @record.mappable
  end
end
