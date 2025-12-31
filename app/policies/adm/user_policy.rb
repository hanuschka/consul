class Adm::UserPolicy < ApplicationPolicy
  def index?
    true
  end

  class Scope < Scope
    def resolve
      scope.active
    end
  end
end
