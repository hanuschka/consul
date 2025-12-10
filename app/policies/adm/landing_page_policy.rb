class Adm::LandingPagePolicy < ApplicationPolicy
  def index?
    true
  end

  def update?
    true
  end

  class Scope < Scope
    def resolve
      scope.landing
    end
  end
end
