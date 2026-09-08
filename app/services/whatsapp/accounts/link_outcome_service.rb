class Whatsapp::Accounts::LinkOutcomeService < ApplicationService
  # What the citizen is told after they followed their login link on the portal.
  # Pushed out of Whatsapp::ConfirmLinkReplyJob rather than answered inside a
  # conversation turn, which is why it keeps the locale copy: there is no inbound
  # message here for an assistant to be answering, and the citizen is standing in
  # a browser waiting to be told whether it worked.
  #
  # The pills are the recovery ones rather than the assistant's, for the same
  # reason the sentence is the locale copy's: there is no turn here for a model to
  # be answering, and a citizen standing in a browser being told the link failed is
  # exactly who must not be left working out what to type. A link that worked
  # offers the way in; one that did not offers another attempt beside it.
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

  def confirmed
    send_bot_line(I18n.t("whatsapp.bot.onboarding.linked"), actions: [:help])

    resume_pending_poll
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
    #
    # Cleared before the ballot is offered rather than after, and the poll re-checked
    # from scratch: registering takes as long as it takes, and a poll that closed in
    # between must leave nothing behind to be resumed on the next link.
    def resume_pending_poll
      poll_id = @conversation.pending_poll_id

      return if poll_id.blank?

      @conversation.clear_pending_poll!

      poll = ::Poll.find_by(id: poll_id)

      return if poll.blank?

      ::Whatsapp::Polls::OfferBallotService.call(
        conversation: @conversation, projekt_phase: poll.projekt_phase
      )
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
