# Opens the review conversation once the material has been gathered and
# analysed. Shared by every AI-negotiated source so a file import and a URL
# import reach the admin as the same screen.
class ProjektImports::StartChatService < ApplicationService
  def initialize(projekt_import:, text_truncated: false)
    @projekt_import = projekt_import
    @text_truncated = text_truncated
  end

  def call
    ai_chat = AiChat.create!(resource: projekt_import)

    initial_message = ProjektImports::BuildInitialMessageService.call(
      projekt_import: projekt_import,
      text_truncated: text_truncated
    )

    if initial_message.success?
      ai_chat.ai_chat_messages.create!(
        role: "assistant",
        content: initial_message.data[:content],
        status: "completed"
      )
    end

    post_title_image_picker(ai_chat)

    projekt_import.update!(status: "chatting")

    ServiceResult.success(ai_chat: ai_chat)
  end

  private

    attr_reader :projekt_import, :text_truncated

    # A message rather than a control in the chrome: the choice is part of what the
    # assistant reports back about the source, and it belongs next to the summary
    # of what it found. The message carries no text of its own — the partial renders
    # the candidates from the import's stored images, so it keeps showing the
    # current choice however often it is re-rendered, and says so when there are
    # none to show.
    def post_title_image_picker(ai_chat)
      ai_chat.ai_chat_messages.create!(
        role: "assistant",
        content: "",
        status: "completed",
        custom_command: ProjektImport::TITLE_IMAGE_PICKER_COMMAND
      )
    end
end
