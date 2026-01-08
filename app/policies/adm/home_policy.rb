class Adm::HomePolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
