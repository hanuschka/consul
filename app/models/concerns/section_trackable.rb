module SectionTrackable
  extend ActiveSupport::Concern

  included do
    after_create :log_section_activity_created
    after_update :log_section_activity_updated
  end

  private

    def log_section_activity_created
      log_section_activity("created")
    end

    def log_section_activity_updated
      meaningful_changes = saved_changes.keys - ["updated_at"]
      return if meaningful_changes.empty?

      log_section_activity("updated", metadata: { changed_fields: meaningful_changes })
    end

    def log_section_activity(action, metadata: {})
      SectionActivity.log(
        user: section_tracking_user,
        section: section_tracking_section,
        trackable: self,
        action: action,
        metadata: metadata
      )
    rescue StandardError => e
      Rails.logger.warn("SectionActivity tracking failed: #{e.message}")
    end
end
