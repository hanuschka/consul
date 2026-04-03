class Adm::ApiRequestLogPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
