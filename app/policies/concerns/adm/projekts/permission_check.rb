module Adm::Projekts::PermissionCheck
  private

  def permitted?
    @user&.has_pm_permission_to?("manage", projekt_from_record)
  end

  module ScopeCheck
    private

    def managed_projekt_ids
      return Projekt.pluck(:id) if @user&.administrator?
      return [] unless @user&.projekt_manager?

      @user.projekt_manager
        .projekt_manager_assignments
        .where("'manage' = ANY(permissions)")
        .pluck(:projekt_id)
    end
  end
end
