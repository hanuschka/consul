class Adm::AppsPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
