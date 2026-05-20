module Adm::Projekts::PermissionCheck
  private

  def manage_permitted?
    @user&.has_pm_permission_to?("manage", projekt_from_record)
  end

  def moderate_permitted?
    @user&.has_pm_permission_to?("moderate", projekt_from_record)
  end

  def create_on_behalf_of_permitted?
    @user&.has_pm_permission_to?("create_on_behalf_of", projekt_from_record)
  end

  def review_permitted?
    @user&.has_pm_permission_to?("review", projekt_from_record)
  end

  module ScopeCheck
    private

    def visible_projekt_ids
      return Projekt.ids if @user&.administrator? || @user&.projekt_manager&.manage_all_projekts?
      return [] unless @user&.projekt_manager?

      @user.projekt_manager
        .projekt_manager_assignments
        .where("permissions && ARRAY[?]::text[]", ProjektManagerAssignment::INTERACTIVE_PERMISSIONS)
        .pluck(:projekt_id)
    end
  end
end
