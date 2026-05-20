class Adm::Projekts::PhaseSettingPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def update?
    manage_permitted?
  end

  private

  def projekt_from_record
    @record.projekt_phase.projekt
  end
end
