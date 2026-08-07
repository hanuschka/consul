class Whatsapp::Flows::HelpService < ApplicationService
  # Catalog E32. One line naming everything the bot does, reachable at any time.
  #
  # It adapts to whether the number is linked: offering "unlink your account" to
  # someone who never linked one contradicts the invitation they were just sent,
  # and offering "link now" to someone already linked is noise.
  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    Whatsapp::Outbound.text(account: account, body: body)
  end

  private

    def account
      @conversation.whatsapp_account
    end

    def body
      I18n.t("whatsapp.bot.compliance.help.#{linked_suffix}")
    end

    def linked_suffix
      account.user_id.present? ? "linked" : "unlinked"
    end
end
