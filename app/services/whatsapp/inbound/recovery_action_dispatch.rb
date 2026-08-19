class Whatsapp::Inbound::RecoveryActionDispatch
  # The three global escape pills — help, cancel, retry. Their gate sits
  # ahead of the catalog-pill gate and of the step dispatcher: a tapped
  # recovery button must not be read as idea text by whichever step happens
  # to be active, and the two tap-id namespaces are built by different
  # modules from different prefixes, so reading this one first can never
  # swallow a catalog pill.
  #
  # `action_id` is the escape the citizen named in words rather than tapped —
  # see FlowActionDispatch for why a named option is dispatched here instead
  # of somewhere of its own.
  def initialize(conversation:, reading:, action_id: nil)
    @conversation = conversation
    @reading = reading
    @action_id = action_id
  end

  # True when a recovery pill was handled.
  def call
    action = Whatsapp::Send.recovery_action_from(@action_id || @reading.tapped_reply_id)

    return false if action.blank?

    case action
    when :help then Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
    when :cancel then Whatsapp::Flows::CancelService.call(conversation: @conversation)
    when :retry then retry_last_action
    end

    true
  end

  private

    # A failed publish leaves the draft intact, so retrying means publishing
    # again; a failed draft leaves nothing behind but the text it was built
    # from.
    #
    # A stored correction is preferred over the original idea: what failed was
    # the edit, and re-drafting from the idea instead would silently throw
    # away the change the citizen asked for. Cleared whenever a first draft is
    # built, so it cannot be re-applied to a draft it never belonged to.
    def retry_last_action
      if @conversation.awaiting_draft_decision? && @conversation.draft_resource.present?
        return Whatsapp::Flows::PublishResultService.call(
          conversation: @conversation, inbound_message_id: @reading.message_id
        )
      end

      if @conversation.last_correction.present?
        return Whatsapp::Flows::BuildDraftService.from_revision(
          conversation: @conversation, correction: @conversation.last_correction,
          inbound_message_id: @reading.message_id
        )
      end

      if @conversation.last_idea_text.present?
        return Whatsapp::Flows::BuildDraftService.from_idea(
          conversation: @conversation, idea_text: @conversation.last_idea_text,
          inbound_message_id: @reading.message_id
        )
      end

      Whatsapp::Flows::MainMenuService.greeting(conversation: @conversation)
    end
end
