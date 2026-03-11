class Adm::UserPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.active
    end
  end
end
