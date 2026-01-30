class Adm::ProposalPolicy < ApplicationPolicy
  def show?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
