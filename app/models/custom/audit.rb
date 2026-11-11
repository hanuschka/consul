load Rails.root.join("app", "models", "audit.rb")

class Audit < Audited::Audit
  before_create :record_api_client

  scope :by_api_client, ->(api_client) { where(comment: api_client_comment(api_client)) }

  # "api_client:12" or "internal_api_client:3": which client made the change.
  def self.api_client_comment(api_client)
    "#{api_client.model_name.singular}:#{api_client.id}"
  end

  # Machine translation writes its output inside MachineTranslation.suppress;
  # those writes are not configuration changes and leave no audit row. The
  # configuration API suppresses it too, but its writes are still audited.
  def self.translation_write_audited?
    Current.api_client.present? || !MachineTranslation.suppressed?
  end

  private

    def record_api_client
      return if Current.api_client.blank?

      self.comment ||= Audit.api_client_comment(Current.api_client)
    end
end
