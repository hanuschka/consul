class Whatsapp::Flows::BaseService < ApplicationService
  # What every flow has in common: it is about one conversation, it usually
  # needs the account behind it to send anything, and when it fails it says so
  # in one voice.
  #
  # Twenty-four flows carried an identical three-line constructor and sixteen an
  # identical `account`, which is the kind of duplication that hides — each copy
  # is too small to notice and the set is too large to keep in step. The AI
  # tools already solved it the same way next door, in
  # Ai::Tools::WhatsappAiAssistant::BaseTool.
  #
  # A flow that needs more than the conversation defines its own constructor and
  # calls super, so @conversation is assigned in exactly one place and a new
  # flow cannot forget it and discover the omission at send time.
  def initialize(conversation:)
    @conversation = conversation
  end

  private

    def account
      @conversation.whatsapp_account
    end

    # The submission being worked on. Five flows had written the same one-liner
    # by the time the location step arrived, which is where a lookup that may
    # one day need a guard or a preload starts drifting.
    def draft_resource
      @conversation.draft_resource
    end

    # One shape for every flow that swallows an exception rather than letting it
    # reach the citizen: the same log prefix, and the conversation id attached
    # so a Sentry issue can be traced back to the chat it happened in.
    def report(exception, action)
      Rails.logger.error("[Whatsapp] #{action} failed: #{exception.class} - #{exception.message}")

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: @conversation.id })
    end
end
