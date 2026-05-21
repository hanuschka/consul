class Adm::Ideas::SettingPolicy < ApplicationPolicy
  include Adm::Ideas::Concerns::IdeaManageable

  def show?
    idea_manager?
  end
end
