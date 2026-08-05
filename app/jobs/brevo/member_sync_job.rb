class Brevo::MemberSyncJob < ApplicationJob
  queue_as :default

  def perform(source = "scheduled", triggered_by_id = nil)
    Brevo::MemberSync.call(source: source, triggered_by: User.find_by(id: triggered_by_id))
  end
end
