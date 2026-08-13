class Ai::Tools::WhatsappAiAssistant::ListOpenPolls < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the votes and surveys open right now, with the link to each and the date it " \
              "closes. Name a project for its own, or pass null for the whole portal. The link is " \
              "how a citizen votes: you cannot cast a vote for them and there is no tool that " \
              "does. Returns facts for you to answer in your own words — it sends nothing to the " \
              "citizen itself."

  params do
    optional :projekt_name,
      description: "The project name as the citizen wrote it, or null for the whole portal" do
      string
    end
  end

  def execute(projekt_name: nil)
    for_named_projekt(projekt_name) do |projekt|
      { polls: ::Whatsapp::OpenPollsQuery.call(projekt: projekt).map { |poll| row_for(poll) }}
    end
  end

  private

    def row_for(poll)
      {
        title: poll.name,
        closes_on: poll.ends_at&.to_date&.iso8601,
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
