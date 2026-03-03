class Adm::ProposalPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def show?
    permitted?
  end

  def update?
    permitted?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.projekt
  end
end
