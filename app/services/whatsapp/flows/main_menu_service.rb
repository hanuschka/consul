class Whatsapp::Flows::MainMenuService < Whatsapp::Flows::BaseService
  # The three things a citizen can start from nothing, under whichever sentence
  # the moment calls for. It replaced IdleGreetingService, which offered the
  # same three buttons and was reachable from one place only — the cancellation
  # and the confirmation after publishing now end in the same menu, and three
  # copies of one button set is what drifts.
  #
  # Two entry points rather than one with a mode: the only thing that differs
  # is the sentence above the buttons and whether an unfinished submission is
  # dropped first, and a caller reading `MainMenuService.call(..., :greeting)`
  # could tell you neither.
  def self.greeting(conversation:)
    conversation.reset_flow!

    new(conversation: conversation, body: greeting_body).call
  end

  # After something was published. Deliberately no reset: publishing already
  # completed the flow, and resetting would drop the projekt the citizen is
  # most likely to submit to again.
  def self.after_publishing(conversation:)
    new(
      conversation: conversation,
      body: Whatsapp::AiAssistant::PhrasingService.call(key: "whatsapp.bot.proposal.next_action")
    ).call
  end

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
