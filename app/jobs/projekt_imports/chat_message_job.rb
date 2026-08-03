class ProjektImports::ChatMessageJob < ApplicationJob
  queue_as :projekt_imports

  def perform(user_message_id)
    user_message = AiChatMessage.find(user_message_id)
    ai_chat = user_message.ai_chat
    projekt_import = ai_chat.resource

    ai_message = ai_chat.ai_chat_messages.find_or_create_by!(
      role: "assistant",
      user_message_id: user_message.id
    ) do |m|
      m.status = "running"
      m.content = ""
    end

    # A retry after the tools already ran must not replay them: the edits are
    # persisted, so re-asking the model would apply them a second time.
    if ai_message.tool_activity.present?
      finish_after_partial_run(ai_message)
      return
    end

    ai_message.update!(status: "running") if ai_message.status != "running"

    ai_chat.update!(running: true)

    result = ProjektImports::ChatResponseService.call(
      projekt_import: projekt_import,
      assistant_message: ai_message
    )

    if result.success?
      ai_message.update!(content: result.data[:content], status: "completed")
    else
      ai_message.update!(content: result.error, status: "error")
    end
  ensure
    ai_chat&.update!(running: false) if ai_chat
  end

  private

  def finish_after_partial_run(ai_message)
    return if ai_message.status == "completed"

    summaries = ProjektImports::AiEditJournal.summarize(ai_message.tool_activity)

    ai_message.update!(
      content: I18n.t("adm.projekts.imports.applied_edits_message", edits: summaries.join("; ")),
      status: "completed"
    )
  end
end
