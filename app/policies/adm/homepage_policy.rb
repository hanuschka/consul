class Adm::HomepagePolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end
end
