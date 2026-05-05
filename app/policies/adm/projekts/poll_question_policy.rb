class Adm::Projekts::PollQuestionPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def create?
    manage_permitted?
  end

  def update?
    manage_permitted?
  end

  def destroy?
    manage_permitted?
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

  def projekt_from_record
    @record.poll&.projekt
  end
end
