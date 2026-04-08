class Adm::ApiClientPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

  def new?
    @user&.administrator?
  end

  def create?
    @user&.administrator?
  end

  def edit?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  def regenerate_token?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
