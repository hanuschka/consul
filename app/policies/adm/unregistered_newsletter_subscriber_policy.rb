class Adm::UnregisteredNewsletterSubscriberPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
