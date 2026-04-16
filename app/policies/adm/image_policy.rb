class Adm::ImagePolicy < ApplicationPolicy
  def update?
    @user&.administrator? || projekt_manager_for_imageable?
  end

  private

  def projekt_manager_for_imageable?
    return false unless @record.imageable.respond_to?(:projekt)

    @user&.has_pm_permission_to?("manage", @record.imageable.projekt)
  end
end
