class Ai::Tools::WhatsappAiAssistant::ListOpenProjekts < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Lists the projekts the portal is currently running, the same ones its own overview " \
              "page shows. This is the answer to a general wish to take part — \"ich möchte mich " \
              "beteiligen\" — because a phase named on its own says nothing about what it is " \
              "for. Name the projekts in your sentence and offer them as view_projekt or " \
              "participate_projekt pills; go into phases with describe_projekt, which returns " \
              "them for one projekt, only for the one the citizen then picks. A citizen who " \
              "already named a projekt has picked one, so answer about that projekt instead of " \
              "listing these. Ten at a time: say how many there are altogether and offer " \
              "more_action_id as a button so the rest are one tap away rather than absent."

  MORE_SCOPE = "open_projekts".freeze

  # A card's subtitle budget is written for one projekt filling a whole message.
  # Ten of them at that length is a page of prompt spent on text the model only
  # needs enough of to tell the projekts apart in one line each.
  SUBTITLE_LENGTH = 160

  params do
    optional :from, description: FROM_DESCRIPTION do
      integer
    end
  end

  def execute(from: 0)
    query = ::Whatsapp::BrowsableProjektsQuery.new(from: from)
    projekts = query.call

    {
      projekts: projekts.map { |projekt| summary_of(projekt) },
      **::Whatsapp::ListWindow.report(
        scope: MORE_SCOPE, from: from, shown: projekts.size, total: query.total
      )
    }
  end

  private

    # `open_for_submission` is the one field the overview cannot be read without:
    # the portal shows a projekt while it is underway, which is a wider rule than
    # the bot's own submission rule, so a projekt listed here may have nothing to
    # contribute to. Offered a submission it would refuse on the next tap — say
    # what it holds and offer the link instead.
    def summary_of(projekt)
      {
        projekt_id: projekt.id,
        projekt: projekt_title(projekt),
        subtitle: ::Whatsapp::ProjektCard.subtitle(projekt, max_length: SUBTITLE_LENGTH),
        open_for_submission: open_phase_counts[projekt.id].positive?,
        url: projekt_url(projekt)
      }.compact
    end
end
