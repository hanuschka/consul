class Adm::NavbarItemPolicy < ApplicationPolicy
  def create?
    true
  end

  def destroy?
    true
  end
end
