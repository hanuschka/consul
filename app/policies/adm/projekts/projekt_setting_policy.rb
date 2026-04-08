class Adm::Projekts::ProjektSettingPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def update?
    permitted?
  end

  private

  def projekt_from_record
    @record.projekt
  end
end
