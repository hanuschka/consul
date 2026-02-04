class Adm::Projekts::PhaseSettingPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
