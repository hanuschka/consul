module Whatsapp::PillPageUrl
  # The page behind a pill that opens one — a phase taken part in on the website,
  # one contribution — for the assistant to put under a reply without ever holding
  # the address. It names the page by the id of the pill the citizen tapped, and the
  # address is looked up here and written in by the bot: a URL handed to a model is
  # a URL a model can rewrite, and a mangled one is a dead end with no symptom until
  # it is tapped.
  #
  # Re-resolved now rather than trusted from the id, under the same rules as the
  # tap itself: a pill sits in a chat history for as long as the chat does. Nil for
  # any other pill, and for a page that is gone or not public yet.
  module_function

  # Written the way the assistant names every other pill ("phase_open-45"), and read
  # through the same parser, which takes the id with or without the prefix it
  # carries on a button.
  def call(spec, user:)
    action, param = ::Whatsapp::AssistantActions.parse(spec)

    return if param.blank?

    case action
    when :phase_open
      phase_url(param)
    when ::Whatsapp::FlowActions::DIRECT_CONTRIBUTION_ACTION
      contribution_url(param, user: user)
    end
  end

  def phase_url(param)
    phase_id, = ::Whatsapp::FlowActions.parse_page_param(param)
    projekt_phase = ::Whatsapp::EligiblePhasesQuery.reachable(phase_id)

    return if projekt_phase.blank?

    ::Whatsapp::ProjektLink.participation_url(projekt_phase)
  end

  def contribution_url(param, user:)
    contribution = ::Whatsapp::ContributionPill.resolve(param, user: user)

    ::Whatsapp::PublishedResourceUrl.call(contribution)
  end
end
