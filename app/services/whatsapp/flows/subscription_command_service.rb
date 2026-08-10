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

    Whatsapp::Outbound.text(account: account, body: body)
  end

  private

    def write
      return Whatsapp::ToggleProjektFollowService.follow(user: account.user, projekt: @projekt) if
        @outcome == :followed

      Whatsapp::ToggleProjektFollowService.unfollow(user: account.user, projekt: @projekt)
    end

    def body
      I18n.t(
        "whatsapp.bot.subscription.#{@outcome}",
        projekt: Whatsapp::ProjektLink.title(@projekt)
      )
    end

    def send_unknown
      Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.subscription.unknown"))
    end
end
