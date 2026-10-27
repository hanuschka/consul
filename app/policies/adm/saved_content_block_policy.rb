class Adm::SavedContentBlockPolicy < ApplicationPolicy
  def create?
    @user&.administrator? || manages_at_least_one_projekt?
  end

  def update?
    return true if @user&.administrator?
    return false unless manages_at_least_one_projekt?
    return false unless @record.is_a?(SavedContentBlock)

    @record.user_id.nil? || @record.user_id == @user.id
  end

  def destroy?
    update?
  end

  private

    def manages_at_least_one_projekt?
      return false unless @user&.projekt_manager?
      return true if @user.projekt_manager.manage_all_projekts?

      @user.projekt_manager
        .projekt_manager_assignments
        .where("permissions && ARRAY[?]::text[]", ["manage"])
        .exists?
    end
end
