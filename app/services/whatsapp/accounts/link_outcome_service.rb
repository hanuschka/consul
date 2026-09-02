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

    # No inbound message is being answered here, but there is a conversation behind the
    # number and it has a language: someone who has only ever written Turkish to this
    # bot is not told in German that their link worked. The body and the labels under
    # it travel in one call, so the sentence and the buttons cannot end up in two
    # different languages.
    def send_bot_line(body, actions:)
      ::Whatsapp::Send.recovery(conversation: @conversation, body: body, actions: actions)
    end
end
