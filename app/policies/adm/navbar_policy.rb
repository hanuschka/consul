class Adm::NavbarPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
