module Whatsapp::DiscardNotes
  # What the assistant is told once the citizen's unfinished work is discarded,
  # whether they tapped the cancel pill or asked in words. One source for both,
  # like Whatsapp::StartOverNotes. Both used to end on one fixed line, which read
  # as the end of the conversation and answered a tap on "Entwurf löschen" with
  # "abgebrochen"; told what went, the assistant can say so and offer the way on.
  #
  # Read before the discard, which clears everything it describes.
  REPLY = "Reply in one or two friendly lines: say what was discarded, naming it — where " \
          "they asked to delete it, confirm that it is deleted — and offer one way on that " \
          "fits, as a button, such as starting afresh where they were. It is not the end of " \
          "the conversation: never word it as a goodbye or as an invitation to write again " \
          "some other time. Do not list what else the portal offers.".freeze

  COMMENT_LINE = "The comment they had written and not yet posted has been discarded; it " \
                 "is gone and cannot be recovered.".freeze

  VOTE_LINE = "They have left the vote they were in the middle of. The answers they " \
              "already gave stay saved.".freeze

  STEP_LINE = "The step they had just begun has been dropped; nothing had been written " \
              "yet.".freeze

  NOTHING = "Nothing was in progress, so nothing was discarded: do not say anything was. " \
            "Answer with the way on from here.".freeze

  # Where the discard was the citizen's yes to leaving it for a contribution they
  # had already asked for (Whatsapp::Conversation#parked_projekt_phase), the way
  # on is that contribution, not a choice of ways.
  PARKED_REPLY = "Say in a few words what was discarded, then carry on with that " \
                 "contribution in the same reply: never ask again for the projekt or for " \
                 "anything they already told you. It is not the end of the " \
                 "conversation.".freeze

  module_function

  def for(conversation)
    discarded = discarded_line(conversation)

    return NOTHING if discarded.blank?

    parked = parked_line(conversation)

    if parked.present?
      return "#{discarded} #{parked} #{PARKED_REPLY}"
    end

    "#{discarded} #{REPLY}"
  end

  # Their words go in whole, because the transcript draws its subject line at the
  # discard and the message that asked is above it.
  def parked_line(conversation)
    projekt_phase = conversation.parked_projekt_phase

    return if projekt_phase.blank?

    asked =
      "They had asked to contribute to #{::Whatsapp::ProjektLink.title(projekt_phase.projekt)} " \
      "instead (start_draft with projekt_phase_id #{projekt_phase.id})"
    text = conversation.parked_submission_text

    if text.blank?
      return "#{asked}, without saying what yet: start it and ask for their idea."
    end

    "#{asked}, writing: \"#{text}\". Start it, and where those words already hold their " \
      "idea, draft it from them as they stand; otherwise ask for it."
  end

  # The draft first, as the larger loss; a vote is left rather than thrown away,
  # because its answers were saved as they were given.
  def discarded_line(conversation)
    if conversation.unsaved_submission?
      draft_line(conversation)
    elsif conversation.pending_comment.present?
      COMMENT_LINE
    elsif conversation.active_poll_id.present? || conversation.pending_poll_id.present?
      VOTE_LINE
    elsif conversation.step_in_progress?
      STEP_LINE
    end
  end

  # Named by its title and its projekt, so the reply can say which draft went.
  # The stash stands in for the record before it is saved.
  def draft_line(conversation)
    title =
      conversation.draft_resource&.title.presence || conversation.draft_data.to_h["title"].presence
    projekt = conversation.projekt_phase&.projekt

    [
      "Their draft contribution",
      title.present? ? "\"#{title}\"" : nil,
      projekt.present? ? "to #{::Whatsapp::ProjektLink.title(projekt)}" : nil,
      "has been discarded; it is gone and cannot be recovered."
    ].compact.join(" ")
  end
end
