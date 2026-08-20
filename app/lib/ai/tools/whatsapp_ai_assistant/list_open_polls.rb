class Ai::Tools::WhatsappAiAssistant::ListOpenPolls < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the votes and surveys open right now, with the link to each and the date it " \
              "closes. Name a project for its own, or pass null for the whole portal. The link is " \
              "how a citizen votes: you cannot cast a vote for them and there is no tool that " \
              "does. Returns facts for you to answer in your own words — it sends nothing to the " \
              "citizen itself. Ten at a time: where there are more, say how many and offer " \
              "more_action_id as a button."

  MORE_SCOPE = "polls".freeze

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  def execute(projekt_name: nil, from: 0)
    for_named_projekt(projekt_name) do |projekt|
      query = ::Whatsapp::OpenPollsQuery.new(projekt: projekt, from: from)
      polls = query.call

      {
        polls: polls.map { |poll| row_for(poll) },
        **::Whatsapp::ListWindow.report(
          scope: MORE_SCOPE, from: from, shown: polls.size, total: query.total
        )
      }
    end
  end

  private

    def row_for(poll)
      {
        title: poll.name,
        closes_on: ::Whatsapp::DatePhrase.absolute(poll.ends_at),
        closes_in: ::Whatsapp::DatePhrase.relative(poll.ends_at),
        projekt: projekt_title(poll.projekt_phase.projekt),
        url: poll_url(poll)
      }.compact
    end

    # Nothing the bot links to is reached through a request, so the host comes
    # from the app's canonical URL options rather than from the caller.
    def poll_url(poll)
      Rails.application.routes.url_helpers.poll_url(poll, **::UrlOptions.default.to_h)
    end
end
