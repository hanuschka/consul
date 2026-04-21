class Adm::StatisticsPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.projekt_manager?
  end
end
