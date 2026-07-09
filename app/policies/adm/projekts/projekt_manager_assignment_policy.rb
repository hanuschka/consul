class Adm::Projekts::ProjektManagerAssignmentPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def update?
    manage_permitted?
  end

  private

  def projekt_from_record
    @record.projekt
  end
end
