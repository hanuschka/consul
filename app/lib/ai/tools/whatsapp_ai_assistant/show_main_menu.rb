class Ai::Tools::WhatsappAiAssistant::ShowMainMenu < Ai::Tools::WhatsappAiAssistant::BaseTool
  # Held apart from show_help, which lists everything the bot can do. This is
  # the three things a citizen starts from nothing, and it is the same menu the
  # flow sends after cancelling and after publishing — a greeting that landed
  # somewhere else would read as a fourth, different menu.
  #
  # Kept alongside reply_with_actions, which can offer a `main_menu` pill but
  # not the menu itself: this one is a list, and a list row carries the
  # description that lets four capabilities be named without a sentence each.
  description "Sends the portal's standing menu as a list. The LAST RESORT for an opening " \
              "message, not the usual answer to one: use it only when you cannot name anything " \
              "more specific — no tool told you what is running, or the citizen's message says " \
              "nothing you can act on at all. \"What can I do here?\" is NOT this: answer it by " \
              "reading what is actually open and replying with reply_with_actions, so the answer " \
              "is in the message rather than behind a button. This sends the message itself — " \
              "do not write your own menu."

  # An open submission is parked rather than refused. This used to answer the
  # model with "they are in the middle of something, hand it to the flow",
  # because the greeting resets the flow and the reset discarded a half-written
  # contribution — so a citizen who genuinely wanted to start again had to
  # cancel first, and one the assistant had misrouted was stuck. Parking keeps
  # the step, the phase and the draft under one key, and the citizen is offered
  # `resume_parked` when they want it back.
  def execute
    park_open_flow!

    ::Whatsapp::Flows::MainMenuService.greeting(conversation: conversation)

    halt("Sent the main menu.")
  end
end
