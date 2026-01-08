class Adm::LandingPagePolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.landing
    end
  end
end
