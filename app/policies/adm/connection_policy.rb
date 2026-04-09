class Adm::ConnectionPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
