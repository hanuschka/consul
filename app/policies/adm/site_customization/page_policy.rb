class Adm::SiteCustomization::PagePolicy < ApplicationPolicy
  def update?
    return true if @user&.administrator?
    return false unless @record.respond_to?(:projekt) && @record.projekt.present?

    @user&.has_pm_permission_to?("manage", @record.projekt)
  end

  class Scope < Scope
    def resolve
      @user&.administrator? ? scope : scope.none
    end
  end
end
