class Adm::SectionSettingPolicy < ApplicationPolicy
  def edit?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end
end
