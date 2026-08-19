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
  #
  # The body is composed against the rows it is about to carry, which is what
  # this service is for now as much as the rows themselves. WhatsApp renders a
  # list as body text plus a single "Auswählen" button and hides every row behind
  # it, so "Willkommen zurück! Was möchten Sie tun?" put the question back to the
  # citizen and filed the answer out of sight — the exact complaint CON-2982
  # opens with. Composed, the sentence names the two or three that fit and the
  # rows stay tappable underneath.
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

  # Its own sentence rather than the portal's configured greeting. That one
  # introduces the bot as an AI assistant, which is something to say once — at
  # first contact, where it now stands — and not above every menu a returning
  # citizen opens.
  GREETING_KEYS = %w[
    whatsapp.bot.welcome_greeting
    whatsapp.bot.free_text_hint
  ].freeze

  # Its own sentence because the greeting's says "welcome back", which is false
  # for a number three messages old — and the disclosure directly above has
  # already introduced the bot, so there is nothing left to say but the question.
  ONBOARDING_KEYS = %w[
    whatsapp.bot.main_menu.onboarding_body
    whatsapp.bot.free_text_hint
  ].freeze

  # The menu after the citizen taps "start over". Its own sentence rather than
  # the greeting's: that one welcomes a returning number back, and this moment is
  # a tap inside a conversation already under way. It used to answer with the
  # cancellation message instead, which read as an ending to someone who had just
  # asked to begin.
  START_OVER_KEYS = %w[
    whatsapp.bot.main_menu.start_over_body
    whatsapp.bot.free_text_hint
  ].freeze

  FOLLOW_UP_KEYS = %w[whatsapp.bot.proposal.next_action].freeze

  # Four entry points rather than one with a mode: what differs is the sentence
  # above the rows and whether an unfinished submission is dropped first, and a
  # caller reading `MainMenuService.call(..., :greeting)` could tell you neither.
  def self.greeting(conversation:)
    conversation.reset_flow!

    new(conversation: conversation, body_keys: GREETING_KEYS).call
  end

  def self.start_over(conversation:)
    conversation.reset_flow!

    new(conversation: conversation, body_keys: START_OVER_KEYS).call
  end

  # The menu that closes the first contact.
  def self.onboarding(conversation:)
    new(conversation: conversation, body_keys: ONBOARDING_KEYS).call
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
    new(conversation: conversation, body_keys: FOLLOW_UP_KEYS).call
  end

  def initialize(conversation:, body_keys:)
    super(conversation: conversation)
    @body_keys = body_keys
  end

  def call
    menu_rows = rows

    Whatsapp::Send.list(
      account: account,
      body: body(menu_rows),
      button_label: I18n.t("whatsapp.bot.buttons.choose_menu"),
      rows: menu_rows
    )
  end

  private

    def body(menu_rows)
      composed(menu_rows).presence || phrased_body
    end

    # The one composition this reply is allowed, spent here rather than by the
    # first of the body's phrases: only here are the rows known, and naming them
    # in the sentence is the whole point. Nil outside the inbound path — a
    # broadcast has no citizen mid-sentence to write for — and nil whenever the
    # composer will not vouch for what came back.
    def composed(menu_rows)
      context = Current.whatsapp_message_context

      return if context.blank?

      Whatsapp::AiAssistant::ComposeReplyService.call(
        fixed_text: locale_body,
        context: context,
        offered_labels: offered_labels(menu_rows)
      )
    end

    # Title and description together, because the description is where a row says
    # what it actually does — "Ihre eigenen Beiträge ansehen" is composable
    # material, "Beiträge" on its own is a heading. The labels themselves are
    # never sent as written: they are the tappable rows, which the criteria
    # require to stay unchanged.
    def offered_labels(menu_rows)
      menu_rows.map do |row|
        [row[:title], row[:description]].compact_blank.join(" — ")
      end
    end

    # What the composition is written from: the plain locale lines, deliberately
    # not routed through Whatsapp.phrase. Reading them through it would attempt a
    # composition per key before this service had assembled the rows, spending
    # the turn's one budgeted call on a greeting that could not name a single
    # option.
    def locale_body
      @body_keys.map { |key| I18n.t(key) }.join("\n\n")
    end

    # The fallback, and the whole of what this method used to be. Reached when
    # composition is off, refused or unavailable — so it still answers, in the
    # portal's address form and with the pre-generated variety, rather than
    # staying silent.
    #
    # Its own per-key composition attempts are no-ops by then: the budget above
    # is already spent, which is what keeps the fallback from paying a second
    # time for the reply it is rescuing.
    def phrased_body
      @body_keys.map { |key| Whatsapp.phrase(key) }.join("\n\n")
    end

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
