class Whatsapp::Flows::MainMenuService < Whatsapp::Flows::BaseService
  # The three things a citizen can start from nothing, under whichever sentence
  # the moment calls for. It replaced IdleGreetingService, which offered the
  # same three buttons and was reachable from one place only — the cancellation
  # and the confirmation after publishing now end in the same menu, and three
  # copies of one button set is what drifts.
  #
  # Two of the three buttons act on a Consul account, so an unlinked number is
  # answered with the help list instead — which offers the same submission
  # entry point plus the invitation to link. Decided here rather than at each
  # call site: three callers wrote the check three ways, and the fourth would
  # have inherited nothing.
  #
  # Two entry points rather than one with a mode: the only thing that differs
  # is the sentence above the buttons and whether an unfinished submission is
  # dropped first, and a caller reading `MainMenuService.call(..., :greeting)`
  # could tell you neither.
  def self.greeting(conversation:)
    conversation.reset_flow!

    return Whatsapp::Flows::HelpService.call(conversation: conversation) if unlinked?(conversation)

    new(conversation: conversation, body: greeting_body).call
  end

  # After something was published. Deliberately no reset: publishing already
  # completed the flow, and resetting would drop the projekt the citizen is
  # most likely to submit to again.
  #
  # A guest submitter gets the confirmation alone rather than the help list:
  # they have just been answered, and following "you're online" with a menu
  # they mostly cannot use reads as a condition attached after the fact.
  def self.after_publishing(conversation:)
    return if unlinked?(conversation)

    new(
      conversation: conversation,
      body: Whatsapp::AiAssistant::PhrasingService.call(key: "whatsapp.bot.proposal.next_action")
    ).call
  end

  def self.unlinked?(conversation)
    conversation.whatsapp_account.user_id.blank?
  end
  private_class_method :unlinked?

  def self.greeting_body
    [::Whatsapp.welcome_greeting, I18n.t("whatsapp.bot.free_text_hint")].join("\n\n")
  end
  private_class_method :greeting_body

  def initialize(conversation:, body:)
    super(conversation: conversation)
    @body = body
  end

  def call
    Whatsapp::Outbound.buttons(
      account: account,
      body: @body,
      buttons: Whatsapp::FlowActions.main_menu_buttons
    )
  end
end
