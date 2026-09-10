class Adm::Projekts::ProjektImportPolicy < ApplicationPolicy
  # An import is private to the admin who started it, with one exception: the
  # people who already reach every projekt — administrators and projekt
  # managers set to manage all projekts — also reach every import, so a
  # colleague's unfinished analysis can be picked up rather than started again.
  def self.all_imports_permitted?(user)
    user&.administrator? || user&.projekt_manager&.manage_all_projekts?
  end

  def destroy?
    self.class.all_imports_permitted?(@user) || @record.user_id == @user&.id
  end

  class Scope < Scope
    def resolve
      return scope.all if Adm::Projekts::ProjektImportPolicy.all_imports_permitted?(@user)

      scope.where(user: @user)
    end
  end
end
