class Adm::Projekts::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.projekt_manager?
  end
end
