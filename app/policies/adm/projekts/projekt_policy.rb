class Adm::Projekts::ProjektPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    @user&.administrator? || @user&.projekt_manager?
  end

  def show?
    manage_permitted?
  end

  def create?
    @user&.administrator? || @user&.projekt_manager?
  end

  def update?
    manage_permitted?
  end

  def destroy?
    manage_permitted?
  end

  class Scope < Scope
    include Adm::Projekts::PermissionCheck::ScopeCheck

    def resolve
      scope.regular
        .where(id: visible_projekt_ids)
        .includes([:projekt_settings, :parent, [page: :translations]])
        .order(updated_at: :desc)
    end
  end

  private

  def projekt_from_record
    @record
  end
end
