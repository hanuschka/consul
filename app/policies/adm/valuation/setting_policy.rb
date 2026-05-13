class Adm::Valuation::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.valuator?
  end
end
