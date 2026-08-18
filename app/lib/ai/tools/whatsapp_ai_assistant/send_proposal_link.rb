class Ai::Tools::WhatsappAiAssistant::SendProposalLink <
  Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Sends the citizen the link to one contribution they named, so they can open it on " \
              "the portal. Use it when they want to see, read or open a specific contribution " \
              "rather than support or comment on it. Returns the candidates when more than one " \
              "matches, so you can ask which they mean; call it again with the clearer wording. " \
              "This sends the message itself — do not write one as well."

  params do
    string :title, description: "What the citizen called the contribution, in their own words"
  end

  def execute(title:)
    matches = ::Whatsapp::SupportableProposalsQuery.call(text: title)

    return no_proposal_match_error(title) if matches.empty?

    if matches.size > 1
      return { candidates: matches.map { |proposal| proposal_candidate_summary(proposal) }}
    end

    send_link(matches.first)
  end

  private

    # The button carries the title, so the citizen reads what they are about to
    # open rather than a bare address. A proposal retired between the search and
    # here has no page to open; the model names it instead of being handed a
    # link that answers with an error.
    def send_link(proposal)
      url = ::Whatsapp::PublishedResourceUrl.call(proposal)

      return not_openable_error(proposal) if url.blank?

      ::Whatsapp::Flows::SendLinkButtonService.call(
        conversation: conversation,
        body: I18n.t("whatsapp.bot.proposal.link.body", title: proposal.title),
        url: url
      )

      halt("Sent the link to this contribution.")
    end

    def not_openable_error(proposal)
      {
        error: "\"#{proposal.title}\" has no public page right now, so there is no link to send. " \
               "Tell the citizen it cannot be opened at the moment."
      }
    end
end
