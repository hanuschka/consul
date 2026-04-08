module Adm::Projekts::PermissionCheck
  private

  def permitted?
    @user&.has_pm_permission_to?("manage", projekt_from_record)
  end

  module ScopeCheck
    private

    def managed_projekt_ids
      return Projekt.ids if @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
      return [] unless @user&.projekt_manager?

      @user.projekt_manager
        .projekt_manager_assignments
        .where("'manage' = ANY(permissions)")
        .pluck(:projekt_id)
    end
  end
end
