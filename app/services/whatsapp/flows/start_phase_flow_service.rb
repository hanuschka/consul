class Whatsapp::Flows::StartPhaseFlowService < Whatsapp::Flows::BaseService
  # Entering a submission is two steps that must not come apart: the flow is
  # stamped on the conversation, and the idea is asked for. Three callers reach it
  # — the phase pill on the discovery list, the assistant's phase tool, and the
  # shortcut for a citizen who named their projekt — and one that did only the
  # first would leave them inside a flow nothing had asked them anything for.
  #
  # Which phase is a fit stays with the caller: each resolves it its own way, by
  # tapped id, by model-supplied id or by name. Whether this citizen may submit to
  # it is not the caller's, and never was — AskIdeaService re-checks that and
  # refuses on its own.
  def initialize(conversation:, projekt_phase:)
    super(conversation: conversation)
    @projekt_phase = projekt_phase
  end

  def call
    @conversation.start_flow!(@projekt_phase)

    Whatsapp::Flows::AskIdeaService.call(conversation: @conversation)
  end
end
