class Adm::Offers::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.offer_manager?
  end
end
