class Adm::MasterportalImportPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.projekt_manager?
  end

  def create?
    show?
  end
end
