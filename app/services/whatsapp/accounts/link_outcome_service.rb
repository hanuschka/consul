class Whatsapp::Accounts::LinkOutcomeService < ApplicationService
  # What the citizen is told after they followed their login link on the portal.
  # Pushed out of Whatsapp::ConfirmLinkReplyJob rather than answered inside a
  # conversation turn: there is no inbound message here, and the citizen is standing
  # in a browser waiting to be told whether it worked.
  #
  # A link that failed keeps the locale copy and the recovery pills, and both for the
  # same reason: nothing has happened for a conversation to be carried on from, and a
  # citizen standing in a browser being told the link failed is exactly who must not
  # be left working out what to type. The retry sits beside the sentence saying why.
  #
  # A link that worked is the other way round. It finished something, so it hands back
  # into the conversation like every other completed action — the fixed line and its
  # one pill are what goes out only where that cannot happen.
  ERROR_REASONS = %w[no_account expired already_linked number_taken].freeze

  def self.confirmed(conversation:)
    new(conversation: conversation).confirmed
  end

  def self.error(conversation:, reason:)
    new(conversation: conversation).error(reason)
  end

  def initialize(conversation:)
    @conversation = conversation
  end

  # A vote that was waiting on the linking is still resumed deterministically, and the
  # fixed line still precedes it: the citizen is standing in a browser having been told
  # nothing yet, and the first question of a ballot is not that.
  #
  # Everything else hands back into the conversation. Linking is never what the citizen
  # came for — it interrupted something — so a line saying it worked with one fixed
  # button beside it leaves them to find their way back to whatever that was. The
  # assistant has the chat above it and picks that up instead.
  def confirmed
    poll = pending_poll

    return resume_ballot(poll) if poll.present?
    return true if carried_on?

    send_linked_line
  end

  def error(reason)
    key = ERROR_REASONS.include?(reason.to_s) ? reason.to_s : "expired"

    send_bot_line(
      I18n.t(
        "whatsapp.bot.onboarding.#{key}", register_url: ::Whatsapp::PortalLinks.register_url
      ),
      actions: %i[link_retry help]
    )
  end

  private

    # The vote the citizen was in the middle of when it turned out they needed an
    # account. Begun again here, under the line saying the link worked, because the
    # link was only ever in the way of it — sending them back to find the projekt
    # again would spend the one moment they were already decided.
    #
    # The ballot rather than one question of it, and where it resumes is read off the
    # answers now recorded against the account they have just linked: a citizen who
    # had already voted on the page picks up where that left them rather than at the
    # first question again.
    def resume_ballot(poll)
      send_linked_line

      ::Whatsapp::Polls::OfferBallotService.call(
        conversation: @conversation, projekt_phase: poll.projekt_phase
      )
    end

    # Cleared before the ballot is offered rather than after, and the poll re-checked
    # from scratch: registering takes as long as it takes, and a poll that closed in
    # between must leave nothing behind to be resumed on the next link.
    def pending_poll
      poll_id = @conversation.pending_poll_id

      return if poll_id.blank?

      @conversation.clear_pending_poll!

      ::Poll.find_by(id: poll_id)
    end

    def carried_on?
      ::Whatsapp::AiAssistant::ContinueConversationService.call(
        conversation: @conversation, note: ::Whatsapp::CompletionNotes.account_linked
      )
    end

    def send_linked_line
      send_bot_line(I18n.t("whatsapp.bot.onboarding.linked"), actions: [:help])
    end

    # No inbound message is being answered here, but there is a conversation behind the
    # number and it has a language: someone who has only ever written Turkish to this
    # bot is not told in German that their link worked. The body and the labels under
    # it travel in one call, so the sentence and the buttons cannot end up in two
    # different languages.
    def send_bot_line(body, actions:)
      ::Whatsapp::Send.recovery(conversation: @conversation, body: body, actions: actions)
    end
end
