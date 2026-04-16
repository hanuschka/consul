class Adm::NewsletterPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def show?
    @user&.administrator?
  end

  def create?
    @user&.administrator?
  end

  def update?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  def deliver?
    @user&.administrator?
  end

  def send_test?
    @user&.administrator?
  end

  def settings?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
