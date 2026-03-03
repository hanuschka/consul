class Adm::SettingPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
