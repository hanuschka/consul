class Adm::ProjektPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
