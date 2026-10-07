module Whatsapp::BallotAnswerRules
  # What becomes of a citizen's answers to a vote, stated as the facts the assistant
  # answers "Kann ich meine Antwort ändern?" and "Was passiert mit meinen Antworten?"
  # from. Before this no tool said any of it, projekt_configuration's "what it does
  # not return is not set" turned the gap into "nicht festgelegt", and three places
  # told the model a vote could not be answered a second time — which is true of
  # restarting a finished ballot in the chat and of nothing else.
  #
  # The portal's rule is the phase's own: an answer is saved the moment it is given,
  # and ProjektPhase#permission_problem lets it be changed or removed on the ballot
  # page until the phase has ended. Nothing makes a ballot final before that, and no
  # setting changes it.
  #
  # English on purpose, like Whatsapp::ParticipationRules: read by a model and never
  # by a person. One source because the projekt configuration, the list of open
  # votes, the ballot state line and the already-voted notes all state it, and a
  # second wording is a second rule to drift.
  SAVED_RULE = "Each answer is saved the moment it is given and counts even if the citizen " \
               "never finishes the ballot. A ballot left part-way can be picked up again, and " \
               "the questions already answered are not asked again.".freeze

  # The chat half of the rule, which is narrower than the page: a tapped option
  # replaces a single-choice answer (Whatsapp::Polls::RecordAnswerService), but
  # nothing in the chat removes one.
  IN_CHAT_RULE = "In this chat, tapping another option under an earlier question replaces a " \
                 "single-choice answer, but a choice cannot be removed here and a ballot " \
                 "answered in full is not asked again here.".freeze

  AFTER_CLOSE_RULE = "Once it has closed, answers can no longer be changed.".freeze

  # Anonymity is ruled out in so many words, because answers are stored with the
  # citizen's account — which is what lets them be changed — and a citizen told
  # otherwise has been told something untrue about their data.
  RESULTS_RULE = "Published results show how many chose each option, never who chose what. " \
                 "Answers are stored with the citizen's account — that is what lets them change " \
                 "them — so never call them anonymous.".freeze

  # The rule as it holds for every vote on the portal, with nothing of one vote in
  # it, for the system prompt to hold without a tool call. Asked "what happens to
  # the answers I gave", the assistant used to ask back which projekt was meant,
  # because the rule only ever reached it through one projekt's configuration.
  PORTAL_RULE = "#{SAVED_RULE} Until a vote closes the citizen can change or remove any of " \
                "their answers on that vote's ballot page on the portal. #{AFTER_CLOSE_RULE} " \
                "#{IN_CHAT_RULE} #{RESULTS_RULE}".freeze

  module_function

  # Keyed on the phase rather than on one poll, because every rule here is the
  # phase's — its end date, its permission check, its evaluation visibility, its
  # open-answer setting — and a phase carrying several ballots has the same rules
  # for all of them. The address is the caller's to pass: the one ballot where
  # there is one, the phase's page where there are several.
  def facts(projekt_phase:, ballot_url:)
    {
      answers_saved: SAVED_RULE,
      changing_answers: change_rule(projekt_phase: projekt_phase, ballot_url: ballot_url),
      results: results_rule(projekt_phase),
      names_in_results: names_rule(projekt_phase)
    }
  end

  # The same facts for one poll in hand, addressed to its own ballot.
  def facts_for_poll(poll)
    facts(projekt_phase: poll.projekt_phase, ballot_url: poll_ballot_url(poll))
  end

  def change_rule_for_poll(poll)
    change_rule(projekt_phase: poll.projekt_phase, ballot_url: poll_ballot_url(poll))
  end

  # The phase's end date rather than the poll's, because the phase's is the one the
  # permission check refuses a change after — and the phase's expiry, for the same
  # reason, is what makes a vote closed here.
  def change_rule(projekt_phase:, ballot_url:)
    end_date = projekt_phase&.end_date
    change_location = where_to_change(ballot_url)

    if projekt_phase&.expired?
      "The vote closed #{::Whatsapp::DatePhrase.relative(end_date)} " \
        "(#{::Whatsapp::DatePhrase.absolute(end_date)}), so answers can no longer be changed."
    elsif end_date.present?
      "Until the vote closes #{::Whatsapp::DatePhrase.relative(end_date)} " \
        "(#{::Whatsapp::DatePhrase.absolute(end_date)}) the citizen can change or remove any " \
        "of their answers #{change_location}. #{IN_CHAT_RULE} #{AFTER_CLOSE_RULE}"
    else
      "The vote has no closing date: while it runs the citizen can change or remove any of " \
        "their answers #{change_location}. #{IN_CHAT_RULE}"
    end
  end

  # The gate the results page itself stands behind (Abilities::Everyone), so the
  # assistant never calls results public that the page would refuse to show.
  def results_rule(projekt_phase)
    if projekt_phase&.evaluation_tab_publicly_visible?("stats")
      "The results of this vote are public on the portal now."
    else
      "The results of this vote are not public yet; the administration decides when they " \
        "are published."
    end
  end

  def names_rule(projekt_phase)
    [RESULTS_RULE, open_answer_names(projekt_phase)].join(" ")
  end

  # The setting Poll#show_open_answer_author_name? reads, asked of the phase
  # directly so a phase with several ballots needs none of them loaded.
  def open_answer_names(projekt_phase)
    if projekt_phase&.feature?("resource.show_open_answer_author_name")
      "Answers written in their own words are shown in the results with their username."
    else
      "Answers written in their own words are shown in the results without a name."
    end
  end

  def where_to_change(ballot_url)
    return "on the vote's page on the portal" if ballot_url.blank?

    "on the ballot page (#{ballot_url})"
  end

  def poll_ballot_url(poll)
    ::Whatsapp::ProjektLink.poll_ballot_url(poll)
  end
end
