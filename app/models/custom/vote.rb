require_dependency Rails.root.join("app", "models", "vote").to_s

class Vote < ActsAsVotable::Vote
  # Catalog B12's "new supports" trigger. Hooked on the vote row rather than in
  # the WhatsApp support flow because supports arrive from the website too, and
  # a citizen who asked to hear about supports on their proposal means all of
  # them.
  #
  # Guarded before enqueueing rather than inside the job: voting is one of the
  # highest-volume writes in the portal, and a portal with the bot switched off
  # should not pay for a queued job per vote.
  after_create_commit :notify_whatsapp_author

  private

    def notify_whatsapp_author
      return if votable_type != "Proposal"
      return if !vote_flag?
      return if !::Whatsapp.enabled?

      Whatsapp::NotifyProposalStatusJob.perform_later(votable_id, "new_supports")
    end
end
