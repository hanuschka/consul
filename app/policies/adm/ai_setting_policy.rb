class Adm::AiSettingPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def update_api_key?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
