class Adm::DocumentPolicy < ApplicationPolicy
  def index?
    @user&.administrator? ||
      @user&.projekt_manager&.manage_all_projekts? ||
      @user&.projekt_manager?
  end

  def show?
    index?
  end

  def create?
    return true if full_access?

    @user&.has_pm_permission_to?("manage", documentable_projekt)
  end

  def update?
    return true if full_access?

    @user&.has_pm_permission_to?("manage", documentable_projekt)
  end

  def destroy?
    return true if full_access?

    @user&.has_pm_permission_to?("manage", documentable_projekt)
  end

  class Scope < Scope
    def resolve
      return scope.all if full_access?
      return scope.none if no_projekt_manager?

      scope.where(documentable_type: "Projekt", documentable_id: visible_projekt_ids)
    end

    private

      def full_access?
        @user&.administrator? ||
          @user&.projekt_manager&.manage_all_projekts?
      end

      def no_projekt_manager?
        @user&.projekt_manager.blank?
      end

      def visible_projekt_ids
        @user.projekt_manager
          .projekt_manager_assignments
          .where(
            "permissions && ARRAY[?]::text[]",
            ProjektManagerAssignment::INTERACTIVE_PERMISSIONS
          )
          .pluck(:projekt_id)
      end
  end

  private

    def full_access?
      @user&.administrator? ||
        @user&.projekt_manager&.manage_all_projekts?
    end

    def documentable_projekt
      if @record.is_a?(Symbol) || @record.is_a?(Class)
        return nil
      end

      documentable = @record.documentable
      return nil if documentable.blank?
      return documentable if documentable.is_a?(Projekt)

      documentable.respond_to?(:projekt) ? documentable.projekt : nil
    end
end
