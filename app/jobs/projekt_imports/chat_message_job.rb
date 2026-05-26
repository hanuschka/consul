class ProjektImports::ChatMessageJob < ApplicationJob
  queue_as :projekt_imports

  def perform(user_message_id)
    user_message = AiChatMessage.find(user_message_id)
    ai_chat = user_message.ai_chat
    projekt_import = ai_chat.resource

    ai_message = ai_chat.ai_chat_messages.create!(
      role: "assistant",
      status: "running",
      user_message_id: user_message.id,
      content: ""
    )

    ai_chat.update!(running: true)

    result = ProjektImports::ChatResponseService.call(projekt_import: projekt_import)

    if result.success?
      ai_message.update!(content: result.data[:content], status: "completed")
    else
      ai_message.update!(content: result.error, status: "error")
    end
  ensure
    ai_chat&.update!(running: false) if ai_chat
  end
end
