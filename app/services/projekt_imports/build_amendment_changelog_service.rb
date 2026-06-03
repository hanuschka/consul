class ProjektImports::BuildAmendmentChangelogService < ApplicationService
  attr_reader :projekt_import

  def initialize(projekt_import:)
    @projekt_import = projekt_import
  end

  def call
    ai_chat = projekt_import.ai_chat
    return ServiceResult.success(summary: nil) if ai_chat.blank?

    user_messages = ai_chat.ai_chat_messages.where(role: "user").count

    if user_messages.zero?
      return ServiceResult.success(summary: I18n.t("adm.projekts.imports.changelog.none"))
    end

    summary = I18n.t(
      "adm.projekts.imports.changelog.with_count",
      count: user_messages
    )

    ServiceResult.success(summary: summary)
  end
end
