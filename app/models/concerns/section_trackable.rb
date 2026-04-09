module SectionTrackable
  extend ActiveSupport::Concern

  included do
    after_create :log_section_activity_created
    after_update :log_section_activity_updated
  end

  private

    def log_section_activity_created
      SectionActivity.log(
        user: section_tracking_user,
        section: section_tracking_section,
        trackable: self,
        action: "created"
      )
    rescue StandardError => e
      Rails.logger.warn("SectionActivity tracking failed: #{e.message}")
    end

    def log_section_activity_updated
      return if saved_changes.keys == ["updated_at"] || saved_changes.empty?

      SectionActivity.log(
        user: section_tracking_user,
        section: section_tracking_section,
        trackable: self,
        action: "updated",
        metadata: { changed_fields: saved_changes.keys - ["updated_at"] }
      )
    rescue StandardError => e
      Rails.logger.warn("SectionActivity tracking failed: #{e.message}")
    end
end
