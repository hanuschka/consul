class Adm::SectionSettingPolicy < ApplicationPolicy
  include Adm::Concerns::AreaManagerForSection

  def index?
    @user&.administrator?
  end

  def update?
    @user&.administrator? || area_manager_for?(@record&.section)
  end
end
