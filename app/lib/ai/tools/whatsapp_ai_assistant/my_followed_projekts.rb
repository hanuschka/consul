class Ai::Tools::WhatsappAiAssistant::MyFollowedProjekts < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the projects this citizen follows, so they are told when something happens " \
              "in them. Use it for questions like which projects do I follow " \
              "or am I following this one, and before manage_subscription when they ask to stop " \
              "following something without naming it. Returns facts for you to answer in your own " \
              "words — it sends nothing to the citizen itself. Ten at a time: where there are " \
              "more, say how many and offer more_action_id as a button."

  MORE_SCOPE = "followed_projekts".freeze

  params do
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  # The same ProjektSubscription rows the website's follow button writes, so a
  # projekt followed on the web is listed here too.
  def execute(from: 0)
    return not_linked_error("have projects it follows") if user.blank?

    query = ::Whatsapp::FollowedProjektsQuery.new(user: user, from: from)
    projekts = query.call

    {
      projekts: projekts.map { |projekt| row_for(projekt) },
      **::Whatsapp::ListWindow.report(
        scope: MORE_SCOPE, from: from, shown: projekts.size, total: query.total
      )
    }
  end

  private

    def row_for(projekt)
      {
        projekt: projekt_title(projekt),
        url: projekt_url(projekt)
      }
    end
end
