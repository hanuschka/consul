class Adm::ImagePolicy < ApplicationPolicy
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

    @user&.has_pm_permission_to?("manage", imageable_projekt)
  end

  def update?
    return true if full_access?

    @user&.has_pm_permission_to?("manage", imageable_projekt)
  end

  def destroy?
    return true if full_access?

    @user&.has_pm_permission_to?("manage", imageable_projekt)
  end

  class Scope < Scope
    def resolve
      return scope.all if full_access?
      return scope.none if no_projekt_manager?

      scope.where(imageable_type: "Projekt", imageable_id: visible_projekt_ids)
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

    def imageable_projekt
      if @record.is_a?(Symbol) || @record.is_a?(Class)
        return nil
      end

      imageable = @record.imageable
      return nil if imageable.blank?
      return imageable if imageable.is_a?(Projekt)

      imageable.respond_to?(:projekt) ? imageable.projekt : nil
    end
end
