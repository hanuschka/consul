class Whatsapp::Flows::MainMenuService < Whatsapp::Flows::BaseService
  # Everything a citizen can start from nothing, under whichever sentence the
  # moment calls for. One list rather than the three buttons it was: none of
  # "submit", "support" and "comment" can be carried out without a projekt, so
  # each was a detour ending at the same choice — they are one row now, and the
  # projekt decides which of the three it leads to.
  #
  # It replaced HelpService as well. The two had grown into the same thing said
  # twice: a list of what the bot does, adapting to whether the number is
  # linked. Keeping both meant a citizen could be shown two different menus
  # depending on which of them answered.
  #
  # The account row is the only difference between linked and unlinked. An
  # unlinked number is not shown a linking row: linking is asked for at the
  # action that needs it, never as a standing invitation (CON-2971).
  ROWS = {
    projekts: :discover,
    participate: :participate,
    contributions: :my_contributions,
    notifications: :notifications_open
  }.freeze

  LINKED_ROW = { unlink: :unlink_start }.freeze

  # The way back into a submission set aside for a side trip, first because it
  # is the one row about something the citizen already started. The assistant is
  # told about a parked flow and can offer it in its own words at a better
  # moment; this is the net under that, for the citizen who ends up at the menu
  # instead — without it, a parked submission is kept and unreachable.
  PARKED_ROW = { resume_parked: :resume_parked }.freeze

  # Three entry points rather than one with a mode: the only thing that differs
  # is the sentence above the rows and whether an unfinished submission is
  # dropped first, and a caller reading `MainMenuService.call(..., :greeting)`
  # could tell you neither.
  def self.greeting(conversation:)
    conversation.reset_flow!

    new(conversation: conversation, body: greeting_body).call
  end

  # The menu after the citizen taps "start over" on the fresh-start question.
  # Its own sentence rather than the greeting's: that one welcomes a returning
  # number back, and this moment is a tap inside a conversation already under
  # way. It used to answer with the cancellation message instead, which read as
  # an ending to someone who had just asked to begin.
  def self.start_over(conversation:)
    conversation.reset_flow!

    new(conversation: conversation, body: start_over_body).call
  end

  # The menu that closes the first contact. Its own sentence because the
  # greeting's says "welcome back", which is false for a number three messages
  # old — and the disclosure directly above has already introduced the bot, so
  # there is nothing left to say but the question.
  def self.onboarding(conversation:)
    new(conversation: conversation, body: onboarding_body).call
  end

  # The menu as a message of its own, after a message that said something —
  # a publish confirmation, a listing of the citizen's contributions.
  # Deliberately no reset: the content message has already dealt with the flow,
  # and resetting would drop the projekt the citizen is most likely to act on
  # next.
  #
  # A separate message rather than pills on the content itself, because an
  # interactive body is capped at a quarter of what a text body holds and
  # nothing truncates it — five contributions with long titles and URLs is
  # enough to have the whole message refused.
  def self.follow_up(conversation:)
    new(
      conversation: conversation,
      body: Whatsapp.phrase("whatsapp.bot.proposal.next_action")
    ).call
  end

  # Its own sentence rather than the portal's configured greeting. That one
  # introduces the bot as an AI assistant, which is something to say once — at
  # first contact, where it now stands — and not above every menu a returning
  # citizen opens.
  def self.greeting_body
    [
      Whatsapp.phrase("whatsapp.bot.welcome_greeting"),
      Whatsapp.phrase("whatsapp.bot.free_text_hint")
    ].join("\n\n")
  end
  private_class_method :greeting_body

  def self.onboarding_body
    [
      Whatsapp.phrase("whatsapp.bot.main_menu.onboarding_body"),
      Whatsapp.phrase("whatsapp.bot.free_text_hint")
    ].join("\n\n")
  end
  private_class_method :onboarding_body

  def self.start_over_body
    [
      Whatsapp.phrase("whatsapp.bot.main_menu.start_over_body"),
      Whatsapp.phrase("whatsapp.bot.free_text_hint")
    ].join("\n\n")
  end
  private_class_method :start_over_body

  def initialize(conversation:, body:)
    super(conversation: conversation)
    @body = body
  end

  def call
    Whatsapp::Send.list(
      account: account,
      body: @body,
      button_label: I18n.t("whatsapp.bot.buttons.choose_menu"),
      rows: rows
    )
  end

  private

    def rows
      parked_rows.merge(ROWS).merge(account_rows).map { |key, action| menu_row(key, action) }
    end

    def parked_rows
      return PARKED_ROW if @conversation.parked_flow?

      {}
    end

    def account_rows
      return LINKED_ROW if account.user_id.present?

      {}
    end

    def menu_row(key, action)
      Whatsapp::FlowActions.row(
        action: action,
        title_key: "whatsapp.bot.main_menu.rows.#{key}.title",
        description_key: "whatsapp.bot.main_menu.rows.#{key}.description"
      )
    end
end
