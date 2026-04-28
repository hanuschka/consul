class Adm::Projekts::ProjektManagerAssignmentPolicy < ApplicationPolicy
  def update?
    @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
  end
end
