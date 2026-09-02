class Adm::Projekts::PollQuestionImportPolicy < ApplicationPolicy
  include Adm::Projekts::PermissionCheck

  def index?
    manage_permitted?
  end

  def new?
    manage_permitted?
  end

  def create?
    manage_permitted?
  end

  def show?
    manage_permitted?
  end

  def apply?
    manage_permitted?
  end

  # An applied import is finished: re-reading the document would put a fresh
  # preview in front of questions that already exist, and applying it again
  # would duplicate them.
  def regenerate?
    manage_permitted? && !@record.applied?
  end

  # Deliberately not narrowed to the author: an import belongs to the phase, and
  # the admins who manage the phase share responsibility for its list.
  def destroy?
    manage_permitted?
  end

  # The list is already narrowed to one phase, so the scope only has to answer
  # the second question: may this admin see that phase's projekt at all.
  class Scope < Scope
    include Adm::Projekts::PermissionCheck::ScopeCheck

    def resolve
      scope.joins(:projekt_phase).where(projekt_phases: { projekt_id: visible_projekt_ids })
    end
  end

  private

    def projekt_from_record
      @record.projekt_phase&.projekt
    end
end
