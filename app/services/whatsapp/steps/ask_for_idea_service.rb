class Whatsapp::Steps::AskForIdeaService < ApplicationService
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    if projekt_phase.blank?
      return Whatsapp::Outbound.text(account: account, body: I18n.t("whatsapp.bot.no_projekt"))
    end

    permission_problem = Whatsapp::ResourceCreationValidationService.call(projekt_phase:, user: account.user)

    if permission_problem.present?
      return Whatsapp::Steps::RefuseParticipationService.call(
        conversation: @conversation,
        reason: permission_problem
      )
    end

    @conversation.update!(step: "awaiting_idea")

    Whatsapp::Outbound.text(
      account: account,
      body: I18n.t("whatsapp.bot.ask_idea", projekt: projekt_phase.projekt.page.title)
    )
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def projekt_phase
      @conversation.projekt_phase
    end
end
