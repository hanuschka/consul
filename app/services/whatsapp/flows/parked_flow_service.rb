class Whatsapp::Flows::ParkedFlowService < Whatsapp::Flows::BaseService
  # The way back into a submission that was set aside — because the citizen
  # asked something else part-way through, or because the assistant put them in
  # the wrong flow and leaving it used to mean losing what they had written.
  #
  # Restores the step and re-asks its question in one message, so returning
  # costs the citizen nothing to read and nothing to remember. A parked flow
  # whose phase has since been deleted has nothing to restore into: the step
  # comes back with no phase, its own service refuses, and the menu answers —
  # the same path a stale draft already takes.
  def self.resume(conversation:)
    new(conversation: conversation).resume
  end

  def resume
    restored_step = @conversation.resume_parked_flow!

    return Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation) if
      restored_step.blank?

    Whatsapp::Flows::StepPromptService.call(conversation: @conversation, step: restored_step)
  end
end
