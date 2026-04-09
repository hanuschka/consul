class Adm::Projekts::ProjektPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    @user&.administrator? || @user&.projekt_manager?
  end

  def show?
    permitted?
  end

  def create?
    permitted?
  end

  def update?
    permitted?
  end

  def destroy?
    permitted?
  end

  class Scope < Scope
    include Adm::Projekts::PermissionCheck::ScopeCheck

    def resolve
      scope.where(id: managed_projekt_ids)
        .includes([:projekt_settings, :parent, [page: :translations]])
        .order(updated_at: :desc)
    end
  end

  private

  def projekt_from_record
    @record
  end
end
