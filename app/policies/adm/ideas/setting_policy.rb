class Adm::Ideas::SettingPolicy < ApplicationPolicy
  def index?
    idea_manager?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end

  private

    def idea_manager?
      @user&.administrator? || @user&.idea_manager?
    end
end
