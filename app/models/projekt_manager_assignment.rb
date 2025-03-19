class ProjektManagerAssignment < ApplicationRecord
  belongs_to :projekt
  belongs_to :projekt_manager

  ACCEPTABLE_PERMISSIONS = %w[manage moderate create_on_behalf_of get_notifications].freeze

  default_scope { order(id: :asc) }

  after_update :sync_permissions_with_dt

  def sync_permissions_with_dt
    if projekt_manager.user.on_dt? && permissions_previously_changed? && ApiClient.active_dt?
      previous_change = permissions_previously_was

      if (previous_change.exclude?("manage") && permissions.include?("manage")) ||
        (previous_change.include?("manage") && permissions.exclude?("manage"))
        Projekts::ProjektManagerPermissionChangedJob.perform_later(self)
      end
    end
  end
end
