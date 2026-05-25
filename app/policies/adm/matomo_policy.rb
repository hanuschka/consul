class Adm::MatomoPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
