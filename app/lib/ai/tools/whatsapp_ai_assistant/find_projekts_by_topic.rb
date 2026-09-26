class Ai::Tools::WhatsappAiAssistant::FindProjektsByTopic < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Finds the projekts that are about a subject the citizen named — \"ich will was " \
              "zum Verkehr sagen\", \"gibt es was zum Stadtpark?\" — matched on what each projekt " \
              "is called, on the names of its phases and ballots, and on the portal's own " \
              "one-line summary of it. The narrower answer " \
              "when a citizen named a subject rather than a projekt: someone who says what they " \
              "want to talk about has already chosen, and handing them the whole overview is " \
              "asking a question they just answered. A wish to take part with no subject in it " \
              "is list_open_projekts. Returns several, because two projekts about one subject " \
              "is the answer rather than a tie, and an error naming what nearly matched when " \
              "the portal holds nothing on it. Identified by subject rather than by id, so it " \
              "reaches finished projekts as well as running ones. Where a row carries a " \
              "matched_phase, the subject named that phase or its ballot rather than the " \
              "projekt: it is the phase the citizen means, so take them into it instead of " \
              "asking which one. Where several rows come back, ask which of them they mean — " \
              "never report that nothing was found."

  # Long enough to keep the length of a whole subtitle out of the prompt ten
  # times over, short enough to tell two projekts on one subject apart.
  SUBTITLE_LENGTH = 160

  params do
    string :topic, description: "The subject the citizen wants to talk about, in their own words"
  end

  def execute(topic:)
    matches = ::Whatsapp::ProjektsByTopicQuery.call(term: topic)

    return no_topic_match_error(topic) if matches.empty?

    {
      topic: topic,
      projekts: matches.map { |match| summary_of(match) },
      hint: ambiguity_hint(matches)
    }.compact
  end

  private

    # Said rather than left to an empty list, because an absent row is not an
    # instruction: the model's next move is a sentence to the citizen and it has
    # nothing else to write it from. What nearly matched travels with the refusal
    # the same way it does for a named projekt — the names are already resolved
    # and ranked by then, and without them the only move left is the overview.
    def no_topic_match_error(topic)
      suggestions = ::Whatsapp::ProjektByNameQuery.suggestions(term: topic)

      {
        error: "No projekt on this portal is about \"#{topic}\". Tell the citizen there is " \
               "nothing on it and offer the open projekts with list_open_projekts.",
        nearly_matched: suggestions.presence
      }.compact
    end

    # `open_for_submission` matters more here than in the overview: this set
    # reaches finished projekts on purpose, so most of what a subject matches has
    # nothing open to contribute to. Offered a submission it would refuse on the
    # next tap — say what came of it and offer the link instead.
    def summary_of(match)
      projekt = match.projekt

      {
        projekt_id: projekt.id,
        projekt: projekt_title(projekt),
        subtitle: ::Whatsapp::ProjektCard.subtitle(projekt, max_length: SUBTITLE_LENGTH),
        open_for_submission: open_phase_counts[projekt.id].positive?,
        url: projekt_url(projekt),
        matched_phase: matched_phase_of(match)
      }.compact
    end

    # The phase whose name the subject actually was, where that is what matched. It
    # carries its own id because that is what start_draft and start_poll_vote take,
    # and without it the model's only move is the card the citizen just came from.
    def matched_phase_of(match)
      return if match.projekt_phase_id.blank?

      { projekt_phase_id: match.projekt_phase_id, phase: match.phase_name }
    end

    # Several projekts on one subject is the answer, and the question that follows it
    # is which one — said here rather than left to the model, because the refusal it
    # used to give instead was the whole of this ticket.
    def ambiguity_hint(matches)
      return if matches.one?

      "Several projekts are about this. Ask the citizen which of them they mean rather than " \
        "reporting that nothing was found."
    end

    # The near-misses, and only when nothing matched: a subject that found its
    # projekts needs no "did you mean", and offering both at once invites a reply
    # that answers the question and second-guesses it in the same breath.
    def suggestions_for(topic, projekts)
      return if projekts.any?

      ::Whatsapp::ProjektByNameQuery.suggestions(term: topic).presence
    end
end
