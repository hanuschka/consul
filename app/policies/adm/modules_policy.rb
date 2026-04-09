class Adm::ModulesPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
