class Ai::Tools::WhatsappAiAssistant::DescribeProjekt < Ai::Tools::WhatsappAiAssistant::BaseTool
  # How much of the projekt's page reaches the model. Past this the page stops
  # being a description and becomes a document, and none of the tail answers the
  # question that was asked.
  DESCRIPTION_LENGTH = 1200

  description "Describes one projekt: what it is about in the portal's own words, which phases " \
              "it has, which of them are running right now, which of them take a contribution " \
              "in the chat, when each of them closes, and where to read more. A phase is " \
              "running when its running field says so, whether or not it takes a written " \
              "contribution — a voting phase that is running is running. Every phase is a row " \
              "of its own, several of the same kind included, each with its own name and its " \
              "own dates: never merge them. " \
              "Identified by name rather than by id, so it reaches finished projekts as " \
              "well as running ones. Returns facts for you to answer in your own words — it " \
              "sends nothing to the citizen. Answer from what it returned and nothing else; a " \
              "projekt with no text here is one to offer the link for rather than to describe. " \
              "It is also what you write a projekt card from: a citizen who picks a projekt is " \
              "answered by send_projekt_card, and the phases and deadlines this returns are " \
              "what its summary carries."

  params do
    string :projekt_name, description: "The projekt name as the citizen wrote it"
  end

  def execute(projekt_name:)
    projekt = readable_projekt(projekt_name)

    return unknown_projekt_error(projekt_name) if projekt.blank?

    {
      projekt: projekt_title(projekt),
      subtitle: ::Whatsapp::ProjektCard.subtitle(projekt),
      description: description_of(projekt),
      phases: phases_of(projekt),
      url: projekt_url(projekt)
    }.compact
  end

  private

    # The projekt's own text, flattened and cut, for the model to summarise in its
    # own words. This used to be a second completion — a summariser called from
    # inside this tool, while the turn held the conversation's advisory lock — so a
    # citizen asking about a projekt waited through two model calls for one answer.
    #
    # Handing over the text instead is cheaper and strictly better: the summary is
    # then written with their actual question in view, which a detached summariser
    # never had.
    def description_of(projekt)
      ::Whatsapp::ProjektCard.description_text(projekt, length: DESCRIPTION_LENGTH)
    end

    # Every phase a citizen may look at, not only the ones that can be contributed
    # to: a closed phase still holds what happened in it, and that is most of what
    # this tool is asked about.
    #
    # Named and dated through Whatsapp::ProjektCard.phase_facts, the same reader the
    # card's rows use, so the summary calls a phase what the row the citizen taps
    # calls it — and so a voting phase arrives under its ballot's name rather than as
    # one of four "Abstimmung".
    #
    # Each row carries the same verdict start_draft will reach, so the model cannot
    # offer a submission into a phase that would refuse it.
    #
    # Whether the phase is running is its own field beside that verdict. The two part
    # company on every phase the bot cannot submit into — a voting phase, a phase whose
    # portal has switched the bot off as a channel — and a summary reading only the
    # verdict called those closed, which is what let four running voting phases arrive
    # as one collective sentence.
    def phases_of(projekt)
      projekt_phases = ::Whatsapp::ProjektPhasesQuery.call(projekt: projekt)
      facts = ::Whatsapp::ProjektCard.phase_facts(projekt_phases)

      projekt_phases.map do |candidate|
        phase_facts = facts[candidate.id]

        {
          projekt_phase_id: candidate.id,
          phase: phase_facts.name,
          ends_on: ::Whatsapp::DatePhrase.absolute(phase_facts.ends_on),
          ends_in: ::Whatsapp::DatePhrase.relative(phase_facts.ends_on),
          running: candidate.current?,
          open_for_submission: ::Whatsapp::EligiblePhasesQuery.eligible?(candidate)
        }.compact
      end
    end
end
