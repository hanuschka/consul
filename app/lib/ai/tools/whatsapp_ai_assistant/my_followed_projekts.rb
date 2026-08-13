class Ai::Tools::WhatsappAiAssistant::MyFollowedProjekts < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the projects this citizen follows, so they are told when something happens " \
              "in them. Takes no arguments. Use it for questions like which projects do I follow " \
              "or am I following this one, and before manage_subscription when they ask to stop " \
              "following something without naming it. Returns facts for you to answer in your own " \
              "words — it sends nothing to the citizen itself."

  # The same ProjektSubscription rows the website's follow button writes, so a
  # projekt followed on the web is listed here too.
  def execute
    return not_linked_error("have projects it follows") if user.blank?

    { projekts: ::Whatsapp::FollowedProjektsQuery.call(user: user).map { |projekt| row_for(projekt) }}
  end

  private

    def row_for(projekt)
      {
        projekt: projekt_title(projekt),
        url: projekt_url(projekt)
      }
    end
end
