class Whatsapp::Flows::AskIdeaService < ApplicationService
  # Catalog C14. The permission check is repeated here rather than trusted from
  # whatever opened the flow: the tap that got here may be minutes or days old,
  # and a phase that closed in between must stop the idea before it costs a
  # draft.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    if projekt_phase.blank?
      return Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.no_projekt"))
    end

    permission_problem =
      Whatsapp::ResourceCreationValidationService.call(projekt_phase: projekt_phase, user: account.user)

    if permission_problem.present?
      return Whatsapp::Flows::RefuseParticipationService.call(
        conversation: @conversation,
        reason: permission_problem
      )
    end

    @conversation.update!(step: "awaiting_idea")

    Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.proposal.ask_idea"))
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def projekt_phase
      @conversation.projekt_phase
    end
end
