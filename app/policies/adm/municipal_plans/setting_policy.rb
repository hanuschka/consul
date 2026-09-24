class Adm::MunicipalPlans::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end
end
