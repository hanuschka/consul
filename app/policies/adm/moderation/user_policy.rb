class Adm::Moderation::UserPolicy < ApplicationPolicy
  def index?
    can_moderate?
  end

  def hide?
    can_moderate? && @record.id != @user.id
  end

  def block?
    can_moderate? && @record.id != @user.id
  end

  class Scope < Scope
    def resolve
      scope.with_hidden
    end
  end
end
