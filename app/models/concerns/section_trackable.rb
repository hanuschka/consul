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

      log_section_activity("updated", metadata: { "changed_fields" => meaningful_changes })
    end

    def log_section_activity(action, metadata: {})
      trackable_name = respond_to?(:title) ? title.to_s.truncate(80) : self.class.model_name.human
      full_metadata = { "trackable_name" => trackable_name }.merge(metadata)

      SectionActivity.log(
        user: Current.user || section_tracking_user,
        section: section_tracking_section,
        trackable: self,
        action: action,
        metadata: full_metadata
      )
    rescue StandardError => e
      Rails.logger.warn("SectionActivity tracking failed: #{e.message}")
    end
end
