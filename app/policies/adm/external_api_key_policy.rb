class Adm::ExternalApiKeyPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

  def edit?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
