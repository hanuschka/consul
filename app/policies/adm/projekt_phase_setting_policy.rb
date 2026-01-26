class Adm::ProjektPhaseSettingPolicy < ApplicationPolicy
  def update?
    @user&.administrator?
  end
end
