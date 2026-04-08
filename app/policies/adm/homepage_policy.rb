class Adm::HomepagePolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
