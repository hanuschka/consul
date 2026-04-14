class Adm::UserPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.active.not_guests
    end
  end
end
