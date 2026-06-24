class Adm::Projekts::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? ||
      (@user&.projekt_manager? && @user.projekt_manager.manage_all_projekts?)
  end
end
