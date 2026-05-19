class Adm::LandingPages::SettingPolicy < ApplicationPolicy
  def show?
    @user&.administrator? || @user&.landing_page_manager?
  end
end
