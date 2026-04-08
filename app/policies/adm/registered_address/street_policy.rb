class Adm::RegisteredAddress::StreetPolicy < ApplicationPolicy
  def search?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
