class Adm::Projekts::InspirationPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.projekt_manager?
  end
end
