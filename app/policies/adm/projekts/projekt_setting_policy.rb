class Adm::Projekts::ProjektSettingPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def update?
    manage_permitted?
  end

  private

  def projekt_from_record
    @record.projekt
  end
end
