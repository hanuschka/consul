class Projekts::ProjektManagerPermissionChangedJob < ApplicationJob
  queue_as :default

  def perform(projekt_manager_assigment)
    DtApi.new.update_projekt_manager_permission(
      projekt_manager_assigment.projekt.id,
      projekt_manager_assigment.projekt_manager.user.id,
      projekt_manager_assigment.permissions.include?("manage")
    )
  end
end
