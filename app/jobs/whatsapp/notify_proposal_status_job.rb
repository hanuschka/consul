class Whatsapp::NotifyProposalStatusJob < ApplicationJob
  queue_as :default

  # Catalog B12. One push for three different events on a citizen's own
  # proposal — a new support, a new comment, a moderation decision — because
  # the message body is the same generic line either way. Which of the three
  # happened only decides whether this citizen asked to hear about it.
  #
  # Deliberately says nothing about what changed: the proposal's title, the
  # support count and the moderation outcome all become visible after tapping
  # through, never on a lock screen.
  NOTIFICATION_TYPES = %i[new_supports new_comments moderation_decision].freeze

  def perform(proposal_id, notification_type)
    return if !::Whatsapp.enabled?

    type = notification_type.to_sym

    return if !NOTIFICATION_TYPES.include?(type)
    return if !Whatsapp::NotificationTemplates.configured?("status_change")

    proposal = Proposal.find_by(id: proposal_id)

    return if proposal.blank?

    deliver(proposal, type)
  end

  private

    def deliver(proposal, type)
      account = audience(proposal, type)

      return if account.blank?

      Whatsapp::Outbound.template(
        account: account,
        name: Whatsapp::NotificationTemplates.name_for("status_change"),
        variables: [Whatsapp::PublishedResourceUrl.call(proposal)],
        projekt_id: proposal.projekt_phase&.projekt_id
      )
    end

    # The author, and only when they are the linked citizen who switched this
    # type on. Everything else the scope already answers: erased users, opted
    # out numbers, unverified links.
    def audience(proposal, type)
      return if proposal.author_id.blank?

      Whatsapp::Account.subscribed_to(type).find_by(user_id: proposal.author_id)
    end
end
