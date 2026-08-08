class Whatsapp::Flows::HelpService < Whatsapp::Flows::BaseService
  # Catalog E32. One line naming everything the bot does, reachable at any time.
  #
  # It adapts to whether the number is linked: offering "unlink your account" to
  # someone who never linked one contradicts the invitation they were just sent,
  # and offering "link now" to someone already linked is noise.
  def call
    Whatsapp::Outbound.text(account: account, body: body)
  end

  private

    def body
      I18n.t("whatsapp.bot.compliance.help.#{linked_suffix}")
    end

    def linked_suffix
      account.user_id.present? ? "linked" : "unlinked"
    end
end
