class Adm::Officing::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.officing_manager?
  end
end
