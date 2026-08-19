class Ai::Tools::WhatsappAiAssistant::AskContinueOrRestart < Ai::Tools::WhatsappAiAssistant::BaseTool
  # The router's half of the fresh-start reading. Offered only where the bot is
  # waiting on free text AND something is half-written
  # (RouterService#fresh_start_available?): anywhere else a greeting is answered
  # by the menu, and with nothing to carry on with the question had both answers
  # empty — "weitermachen" returned to nothing and "neu anfangen" discarded
  # nothing (CON-2981).
  #
  # Held apart from show_main_menu, which the model would otherwise reach for:
  # that one sets an open submission aside and answers with the three starting
  # points. This is what the citizen who greets mid-submission is owed instead —
  # the choice, before anything is set aside or discarded.
  #
  # Deliberately not hand_to_flow with decision answer: that is how "hallo"
  # became the text of a contribution in the first place (CON-2968).
  description "Asks the citizen whether they want to carry on with what they were doing or " \
              "start again, and waits for their answer. It is offered only when they really " \
              "do have something half-written, so its presence is itself the answer to whether " \
              "there is anything to carry on with. Call it when the bot is waiting for them to " \
              "write something and their message carries no substance of its own — a " \
              "bare greeting (\"hallo\", \"guten morgen\", \"hi\"), a question about you (\"was " \
              "kannst du?\"), or a request for the menu (\"menü\", \"von vorne\"). A message " \
              "that carries substance alongside the greeting is not this: \"Hallo, ich möchte " \
              "mehr Bänke am Rummelgang\" is the contribution itself, and so is any short " \
              "answer to the step's question — \"mehr Bänke\", \"am Bahnhof\", \"kein Foto\". " \
              "Asking to abandon the submission is abort_submission, not this. When in doubt " \
              "between this and hand_to_flow, hand to the flow. This sends the question with " \
              "its buttons — do not write one as well."

  def execute
    ::Whatsapp::Flows::ContinueOrRestartService.ask(conversation: conversation)

    halt("Asked whether to carry on or start again.")
  end
end
