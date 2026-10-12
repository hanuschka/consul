class Whatsapp::Drafting::ResendPreviewService < ApplicationService
  # The draft shown again as it stands, for a citizen who tapped the publishing
  # pill under a preview of an earlier version (Whatsapp::PreviewVersion). Nothing
  # is published on that tap — what they said yes to is not what would go in — so
  # they are answered with the preview they would have needed instead. Sent from
  # here rather than left to the assistant to remember, and through the same tool
  # every preview goes through, so the block, the picture, the stored digest and
  # the pills are the ones any other preview carries.
  #
  # The question and the note on the additions are fixed lines, because no model
  # is asked anything on this tap. True when the preview went out.
  QUESTION_KEY = "whatsapp.bot.preview.outdated_question".freeze
  ADDITIONS_NOTE_KEY = "whatsapp.bot.preview.outdated_additions_note".freeze

  # Every label here is fixed, so none is written.
  BUTTONS = [
    { "action_id" => "draft_publish", "label" => "" },
    { "action_id" => "draft_revise", "label" => "" },
    { "action_id" => "cancel", "label" => "" }
  ].freeze

  def initialize(conversation:)
    @conversation = conversation
  end

  def call
    question, additions_note = ::Whatsapp::AiAssistant::BotCopyService.call(
      account: @conversation.whatsapp_account, lines: written_lines
    )

    tool = ::Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation.new(
      conversation: @conversation
    )

    tool
      .call(question: question, buttons: BUTTONS, **{ additions_note: additions_note }.compact)
      .is_a?(::ToolHalt)
  end

  private

    # The note only where the draft carries additions, which is where the tool
    # refuses to show it without one.
    def written_lines
      additions = @conversation.additions_beyond_idea
      question = ::Whatsapp.copy(QUESTION_KEY)

      return [question] if additions.blank?

      [question, ::Whatsapp.copy(ADDITIONS_NOTE_KEY, additions: additions.join(", "))]
    end
end
