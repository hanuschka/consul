class Adm::SiteCustomization::PagePolicy < ApplicationPolicy
  def update?
    return true if @user&.administrator?
    return false unless @record.projekt.present?

    @user&.has_pm_permission_to?("manage", @record.projekt)
  end
end
