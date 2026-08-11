class Whatsapp::Flows::ConfirmSubmissionService < Whatsapp::Flows::BaseService
  # The last look before anything is published, and the only step that shows
  # the citizen the picture rather than describing it. Reached from the two
  # image branches: an uploaded photo may be the wrong one, and a generated
  # image is the one part of the submission nobody has seen yet.
  #
  # Skipping straight to publishing was the old behaviour and cost the citizen
  # the only chance to catch either — a published proposal cannot be edited
  # from the chat.
  def call
    @conversation.update!(step: "awaiting_final_confirmation")

    # A nil header leaves the same message without the picture rather than
    # risking the send: WhatsApp fetches it from us while the send is in flight
    # and refuses the whole message over one it cannot render.
    Whatsapp::Outbound.buttons(
      account: account,
      body: body,
      buttons: buttons,
      header_image_url: Whatsapp::DraftCard.image_url(draft_resource)
    )
  end

  private

    def draft_resource
      @conversation.draft_resource
    end

    def body
      [
        Whatsapp::DraftCard.body(
          draft_resource, intro_key: "whatsapp.bot.proposal.preview_intro"
        ),
        Whatsapp::AiAssistant::PhrasingService.call(
          key: "whatsapp.bot.proposal.preview_question"
        )
      ].join("\n\n")
    end

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :submit_final, label_key: "whatsapp.bot.buttons.submit_final"
        ),
        Whatsapp::Outbound.recovery_button(:cancel)
      ]
    end
end
