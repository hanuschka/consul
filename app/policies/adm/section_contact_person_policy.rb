class Adm::SectionContactPersonPolicy < ApplicationPolicy
  def index?
    section_admin_or_manager?
  end

  def new?
    create?
  end

  def create?
    section_admin_or_manager?
  end

  def edit?
    update?
  end

  def update?
    section_admin_or_manager?
  end

  def destroy?
    section_admin_or_manager?
  end

  def search?
    return true if @user&.administrator?

    # Class-level authorize ([:adm, SectionContactPerson]) has no concrete section
    # context. Permit any area-manager — the row-level create/update checks below
    # still restrict actual mutations to the manager's own section.
    Adm::Section::MANAGER_PREDICATES.values.any? { |pred| @user&.public_send(pred) }
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def section_admin_or_manager?
      return true if @user&.administrator?

      predicate = Adm::Section::MANAGER_PREDICATES[record_section]
      predicate.present? && @user&.public_send(predicate)
    end

    def record_section
      return nil unless @record

      if @record.is_a?(Class)
        # Class-level authorize (e.g. for #search): no instance, fall back to request params.
        nil
      else
        @record.section
      end
    end
end
