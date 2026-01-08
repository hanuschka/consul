class Adm::ProjektManagerPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
