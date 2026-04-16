class Adm::AdministratorPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
