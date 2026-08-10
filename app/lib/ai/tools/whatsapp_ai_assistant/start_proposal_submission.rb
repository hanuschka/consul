class Ai::Tools::WhatsappAiAssistant::StartProposalSubmission < Ai::Tools::WhatsappAiAssistant::BaseTool
  description "Offers the citizen the phases that are open for submissions, for when they want " \
              "to submit something but have not said which projekt. One open phase is sent as " \
              "its card with a button that starts the submission, several as a selectable list, " \
              "none as a notice that says when the next one will be announced. This sends the " \
              "message itself — do not write one as well, and do not ask which projekt they mean."

  def execute
    ::Whatsapp::Flows::SubmitProposalService.call(conversation: conversation)

    halt("Offered the citizen the phases that are open for submissions.")
  end
end
