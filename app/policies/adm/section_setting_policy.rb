class Adm::SectionSettingPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end
end
