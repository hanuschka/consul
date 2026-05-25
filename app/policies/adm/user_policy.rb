class Adm::UserPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def edit?
    @user&.administrator?
  end

  def update?
    edit?
  end

  def verify?
    edit?
  end

  def unverify?
    edit?
  end

  class Scope < Scope
    def resolve
      scope.actual
    end
  end
end
