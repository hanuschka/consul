class Adm::RecipientGroupPolicy < ApplicationPolicy
  def index?
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

  def create_filter?
    @user&.administrator?
  end
  alias_method :update_filter?, :create_filter?
  alias_method :destroy_filter?, :create_filter?
  alias_method :reorder_filters?, :create_filter?
  alias_method :recount_filters?, :create_filter?

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
