class LegislationDraftVersionSerializer < BaseSerializer
  attr_reader :draft_version

  def initialize(draft_version)
    @draft_version = draft_version
  end

  def serialize
    {
      id: draft_version.id,
      legislation_process_id: draft_version.legislation_process_id,
      title: draft_version.title,
      changelog: draft_version.changelog,
      body: draft_version.body,
      body_html: sanitized_body_html,
      status: draft_version.status,
      created_at: draft_version.created_at,
      updated_at: draft_version.updated_at
    }
  end

  private

    def sanitized_body_html
      return if draft_version.body.blank?

      AdminLegislationSanitizer.new.sanitize(draft_version.body_html)
    end
end
