class Whatsapp::Flows::SubscriptionCommandService < Whatsapp::Flows::BaseService
  # Catalog D29 and D30. Subscription management is a typed command with no menu
  # to navigate, so the whole flow is: resolve the name, write the state, say
  # what happened and how to undo it.
  #
  # Two entry points because the two commands are two commands — the citizen
  # said which one they wanted, and turning that back into a toggle would make
  # "Subscribe X" twice unsubscribe them.
  def self.subscribe(conversation:, projekt:)
    new(conversation: conversation, projekt: projekt, outcome: :followed).call
  end

  def self.unsubscribe(conversation:, projekt:)
    new(conversation: conversation, projekt: projekt, outcome: :unfollowed).call
  end

  def initialize(conversation:, projekt:, outcome:)
    super(conversation: conversation)
    @projekt = projekt
    @outcome = outcome
  end

  def call
    return send_unknown if @projekt.blank?

    write

    Whatsapp::Send.text(account: account, body: body)
  end

  private

    # Writes the same ProjektSubscription row the website's follow button
    # writes, so following in the chat and following on the site are one state
    # rather than two that disagree. Rows are deactivated rather than
    # destroyed, which is what the web side does and what keeps an unfollow
    # reversible. The commands name the state they want rather than asking for
    # a flip, so repeating one is a no-op instead of undoing what it just did.
    def write
      ::ProjektSubscription
        .find_or_initialize_by(user: account.user, projekt: @projekt)
        .update!(active: @outcome == :followed)
    end

    def body
      Whatsapp.phrase("whatsapp.bot.subscription.#{@outcome}", projekt: Whatsapp::ProjektLink.title(@projekt))
    end

    def send_unknown
      Whatsapp::Send.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.subscription.unknown")
      )
    end
end
