class Adm::AdminAssetPolicy < ApplicationPolicy
  def index?
    @user&.administrator? || @user&.projekt_manager?
  end

  def show?
    index?
  end

  def create?
    return true if @user&.administrator?

    pm_manage_allowed?
  end

  def update?
    return true if @user&.administrator?

    pm_manage_allowed?
  end

  def destroy?
    return true if @user&.administrator?

    pm_manage_allowed?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user&.administrator?
      return scope.none if user&.projekt_manager.blank?
      return scope.where.not(projekt_id: nil) if user.projekt_manager.manage_all_projekts?

      scope.where(projekt_id: visible_projekt_ids)
    end

    private

      def visible_projekt_ids
        user.projekt_manager
          .projekt_manager_assignments
          .where(
            "permissions && ARRAY[?]::text[]",
            ProjektManagerAssignment::INTERACTIVE_PERMISSIONS
          )
          .pluck(:projekt_id)
      end
  end

  private

    def pm_manage_allowed?
      projekt = record_projekt
      return false if projekt.blank?

      @user&.has_pm_permission_to?("manage", projekt)
    end

    def record_projekt
      return nil if @record.is_a?(Symbol) || @record.is_a?(Class)

      @record.projekt
    end
end
