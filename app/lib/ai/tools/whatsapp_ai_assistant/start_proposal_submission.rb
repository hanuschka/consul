class Ai::Tools::WhatsappAiAssistant::StartProposalSubmission <
  Ai::Tools::WhatsappAiAssistant::BaseTool

  description "Starts a submission. Pass projekt_name when the citizen named the project they " \
              "mean and the submission begins there straight away; pass null when they did not, " \
              "and the phases open for submissions are offered instead — one as its card with a " \
              "button, several as a selectable list, none as a notice saying when the next will " \
              "be announced. With null and more phases open than a list can hold, nothing is sent " \
              "and you are told to ask which project they mean. This sends the message itself — " \
              "do not write one as well, and do not ask which projekt they mean unless this tool " \
              "tells you to."

  params do
    optional :projekt_name,
      description: "The project the citizen named, as they wrote it, or null when they named none" do
      string
    end
  end

  # A submission already open is parked first. Entering a flow calls start_flow!,
  # which replaces the whole context — so before parking existed, a citizen who
  # said "actually I want to suggest something for the other projekt" lost the
  # draft they were part-way through, silently and with no way back.
  def execute(projekt_name: nil)
    return start_named_submission(projekt_name) if projekt_name.present?
    return too_many_to_list_error if all_open_projekt_phases.size > ::Whatsapp::MAX_LIST_ROWS

    park_open_flow!

    ::Whatsapp::Flows::SubmitProposalService.call(conversation: conversation)

    halt("Offered the citizen the phases that are open for submissions.")
  end

  private

    # The named projekt enters its flow directly rather than being offered back as
    # a one-row list: the citizen has already chosen, and a list that repeats their
    # own answer to them is a step for nothing.
    def start_named_submission(projekt_name)
      projekt_phase = named_open_phase(projekt_name)

      return unknown_open_projekt_error if projekt_phase.blank?

      park_open_flow!

      ::Whatsapp::Flows::StartPhaseFlowService.call(
        conversation: conversation, projekt_phase: projekt_phase
      )

      halt("Started the submission in projekt phase #{projekt_phase.id}.")
    end

    # A WhatsApp list holds ten rows and the bot has nowhere to paginate to, so
    # past ten the list stops being an offer and becomes a truncation: the
    # eleventh open phase could never be tapped, whatever the citizen did. Asking
    # which projekt they mean is the only way to reach it, and this is the one case
    # where the model does the asking.
    def too_many_to_list_error
      { error: "#{all_open_projekt_phases.size} phases are open, more than one list can hold. " \
               "Ask the citizen which project they want to contribute to, then call this again " \
               "with projekt_name." }
    end

    # Held apart from the general unknown-projekt error: this one is about a
    # projekt that may well exist and simply not be taking submissions, and the
    # model has to be able to say that rather than "no such project".
    def unknown_open_projekt_error
      { error: "No single project open for submissions matches that name. It may exist without " \
               "taking submissions right now — call describe_projekt to check — or the name may " \
               "match several. Do not guess which one they meant." }
    end
end
