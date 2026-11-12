class Adm::Offers::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
