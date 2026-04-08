class Adm::Projekts::ProjektEventPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def create?
    permitted?
  end

  def update?
    permitted?
  end

  def destroy?
    permitted?
  end

  def send_notifications?
    permitted?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.projekt_phase&.projekt
  end
end
