class Whatsapp::Flows::AskIdeaService < Whatsapp::Flows::BaseService
  # Catalog C14. The permission check is repeated here rather than trusted from
  # whatever opened the flow: the tap that got here may be minutes or days old,
  # and a phase that closed in between must stop the idea before it costs a
  # draft.
  def call
    if projekt_phase.blank?
      return Whatsapp::Outbound.text(
        account: account,
        body: Whatsapp.phrase("whatsapp.bot.no_projekt")
      )
    end

    permission_problem =
      Whatsapp::Drafting::ResourceCreationValidationService.call(projekt_phase: projekt_phase, user: author)

    if permission_problem.present?
      return Whatsapp::Flows::RefuseParticipationService.call(
        conversation: @conversation,
        reason: permission_problem
      )
    end

    @conversation.update!(step: "awaiting_idea")

    Whatsapp::Outbound.text(
      account: account,
      body: Whatsapp.phrase("whatsapp.bot.proposal.ask_idea")
    )
  end

  private

    def projekt_phase
      @conversation.projekt_phase
    end

    def author
      @author ||= Whatsapp::Drafting::SubmissionAuthorService.call(conversation: @conversation)
    end
end
