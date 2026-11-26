class Adm::RecipientGroupPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def create?
    @user&.administrator?
  end

  def update?
    @user&.administrator? && editable_group?
  end

  def destroy?
    @user&.administrator? && editable_group?
  end

  def create_filter?
    @user&.administrator? && editable_group?
  end
  alias_method :update_filter?, :create_filter?
  alias_method :destroy_filter?, :create_filter?
  alias_method :reorder_filters?, :create_filter?

  def recount_filters?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def editable_group?
      !@record.projekt_subscribers_group?
    end
end
