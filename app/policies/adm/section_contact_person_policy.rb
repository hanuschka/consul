class Adm::SectionContactPersonPolicy < ApplicationPolicy
  include Adm::Concerns::AreaManagerForSection

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
    AREA_MANAGER_PREDICATES.values.any? { |pred| @user&.public_send(pred) }
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end

  private

    def section_admin_or_manager?
      return true if @user&.administrator?

      area_manager_for?(record_section)
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
