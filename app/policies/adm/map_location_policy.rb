class Adm::MapLocationPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
