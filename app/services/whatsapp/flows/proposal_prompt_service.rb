class Whatsapp::Flows::ProposalPromptService < Whatsapp::Flows::BaseService
  # Catalog C13, for the one open phase. Sent as the projekt card rather than as
  # a sentence naming the projekt: this is the moment the citizen decides
  # whether that projekt is theirs, and a title with no picture and no page
  # behind it is not enough to decide on.
  #
  # The flow is not started here. Both buttons carry what they act on, and
  # "View project" must be able to answer without committing the citizen to a
  # submission they have not agreed to yet.
  def initialize(conversation:, projekt_phase:)
    super(conversation: conversation)
    @projekt_phase = projekt_phase
  end

  def call
    Whatsapp::Flows::SendProjektCardService.call(
      conversation: @conversation,
      projekt: @projekt_phase.projekt,
      buttons: buttons
    )
  end

  private

    def buttons
      [
        Whatsapp::FlowActions.button(
          action: :view_projekt,
          label_key: "whatsapp.bot.buttons.view_projekt",
          param: @projekt_phase.projekt_id
        ),
        Whatsapp::FlowActions.button(
          action: :idea_start,
          label_key: "whatsapp.bot.buttons.idea_start",
          param: @projekt_phase.id
        )
      ]
    end
end
