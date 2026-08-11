# frozen_string_literal: true

# This is the base class for all Pundit policies. It provides a set of default
# methods that can be overridden in the actual policy classes.
class ApplicationPolicy
  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Leaving an internal note. Defaults to the right to change the resource, so a policy that does
  # not care about the distinction behaves exactly as before.
  def add_memo?
    update?
  end

  # Base scope class for all Pundit policies.
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

      attr_reader :user, :scope
  end

  private

    def can_moderate?
      return false unless @user

      @user.moderator? || @user.administrator?
    end
end
