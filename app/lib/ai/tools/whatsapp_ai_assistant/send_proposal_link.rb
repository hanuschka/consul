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

  # Resolved through the openable search rather than the supportable one: what a
  # citizen wants to open is any Beitrag, and a budget investment is one — the
  # supportable search knows only proposals, because supporting an investment is
  # budget voting rather than a support click.
  def execute(title:)
    matches = ::Whatsapp::OpenableContributionsQuery.call(text: title)

    return no_contribution_match_error(title) if matches.empty?

    if matches.size > 1
      return { candidates: matches.map { |match| contribution_candidate_summary(match) }}
    end

    send_link(matches.first)
  end

  private

    # The button carries the title, so the citizen reads what they are about to
    # open rather than a bare address. A Beitrag retired or hidden between the
    # search and here has no page to open; the model names it instead of being
    # handed a link that answers with an error.
    def send_link(contribution)
      url = ::Whatsapp::PublishedResourceUrl.call(contribution)

      return not_openable_error(contribution) if url.blank?

      ::Whatsapp::Flows::SendLinkButtonService.call(
        conversation: conversation,
        body: I18n.t("whatsapp.bot.proposal.link.body", title: contribution.title),
        url: url
      )

      halt("Sent the link to this contribution.")
    end

    def not_openable_error(contribution)
      {
        error: "\"#{contribution.title}\" has no public page right now, so there is no link to " \
               "send. Tell the citizen it cannot be opened at the moment."
      }
    end
end
