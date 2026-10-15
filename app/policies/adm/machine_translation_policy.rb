class Adm::MachineTranslationPolicy < ApplicationPolicy
  def index?
    @user&.administrator?
  end

  def destroy?
    @user&.administrator?
  end

  class Scope < Scope
    def resolve
      scope
    end
  end
end
