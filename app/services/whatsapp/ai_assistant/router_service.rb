class Whatsapp::AiAssistant::RouterService < ApplicationService
  # Raised rather than returned: a model that keeps reading without ever
  # answering would hold the conversation lock and spend the budget for as long
  # as it kept going, and the caller's fallback is a better reply than none.
  class ToolLoopError < StandardError; end

  # The provider default is 300 seconds, written for a generation nobody waits
  # on. This one is waited on by a held advisory lock.
  REQUEST_TIMEOUT_SECONDS = 30
  MAX_TOOL_CALLS = 5

  BLANK_MESSAGE_ERROR = "nothing to route".freeze
  EMPTY_ANSWER_ERROR = "assistant produced no reply".freeze

  def initialize(conversation:, inbound_text:, inbound_message_id: nil)
    @conversation = conversation
    @inbound_text = inbound_text
    @inbound_message_id = inbound_message_id
    @tool_calls_made = 0
  end

  def call
    return ServiceResult.failure(error: BLANK_MESSAGE_ERROR) if @inbound_text.blank?

    chat = build_chat

    # After the chat is assembled, so the bubble covers the wait the citizen
    # actually experiences rather than the prompt building that precedes it.
    ::Whatsapp::Outbound.typing(message_id: @inbound_message_id)

    response = chat.ask(@inbound_text)
    outcome = deliver(response)

    persist(chat, response)

    return ServiceResult.failure(error: EMPTY_ANSWER_ERROR) if outcome == :empty

    ServiceResult.success(outcome: outcome)
  rescue StandardError => e
    report(e)

    ServiceResult.failure(error: e.message)
  end

  private

    def build_chat
      chat = ::Ai::RubyLlmFactory.fast_chat(REQUEST_TIMEOUT_SECONDS)

      chat.with_instructions(instructions)
      chat.with_tools(*tools)
      chat.on_tool_call { |tool_call| track_tool_call(tool_call) }

      state.replay_into(chat)
    end

    def instructions
      ::Whatsapp::AiAssistant::SystemPromptService.call(conversation: @conversation)
    end

    # Logged per call because which tool the model picked is the only way to see
    # a misroute after the fact: the citizen's reply looks reasonable either way,
    # and nothing else records that "show me the projekts" ended in the menu.
    def track_tool_call(tool_call)
      @tool_calls_made += 1

      Rails.logger.info(
        "[Whatsapp] assistant conversation=#{@conversation.id} tool=#{tool_call.name}"
      )

      return if @tool_calls_made <= MAX_TOOL_CALLS

      raise ToolLoopError, "assistant called more than #{MAX_TOOL_CALLS} tools in one turn"
    end

    # Every tool that speaks to the citizen halts the loop, so reaching a plain
    # message here means nothing has been sent yet and the model's own text is
    # the whole reply.
    def deliver(response)
      return :flow if hand_to_flow.requested?
      return :tool if response.is_a?(::RubyLLM::Tool::Halt)

      body = response.content.to_s.strip

      return :empty if body.blank?

      ::Whatsapp::Outbound.text(account: @conversation.whatsapp_account, body: body)

      :answered
    end

    # Kept out of the turn's own rescue. By the time state is written the citizen
    # has already been answered, so reporting the turn as failed would have the
    # caller answer them a second time out of the deterministic flow — losing the
    # history is the far smaller failure.
    def persist(chat, response)
      save_state(chat, response)
    rescue StandardError => e
      report(e)
    end

    # A halted turn ends on a tool result with nothing after it. The note keeps
    # the stored history in the shape every provider expects, and tells the next
    # turn what was already done rather than leaving it to guess from arguments.
    def save_state(chat, response)
      if response.is_a?(::RubyLLM::Tool::Halt)
        chat.add_message(role: :assistant, content: response.to_s)
      end

      state.save!(chat)
    end

    def state
      @state ||= ::Whatsapp::AiAssistant::ChatState.new(conversation: @conversation)
    end

    def tools
      [
        ::Ai::Tools::WhatsappAiAssistant::ListOpenPhases,
        ::Ai::Tools::WhatsappAiAssistant::CheckParticipationEligibility,
        # The read half. Everything above answers "what can I do here" and
        # everything below acts; these answer "what is this portal doing", which
        # until they existed was refused as out of scope for want of a tool.
        ::Ai::Tools::WhatsappAiAssistant::DescribeProjekt,
        ::Ai::Tools::WhatsappAiAssistant::ListProjektResults,
        ::Ai::Tools::WhatsappAiAssistant::ListMilestones,
        ::Ai::Tools::WhatsappAiAssistant::ListEvents,
        ::Ai::Tools::WhatsappAiAssistant::ListOpenPolls,
        ::Ai::Tools::WhatsappAiAssistant::ListProjektContributions,
        ::Ai::Tools::WhatsappAiAssistant::MyFollowedProjekts,
        ::Ai::Tools::WhatsappAiAssistant::ShowProjekts,
        ::Ai::Tools::WhatsappAiAssistant::SendProjektCard,
        ::Ai::Tools::WhatsappAiAssistant::StartProposalSubmission,
        ::Ai::Tools::WhatsappAiAssistant::StartPhaseFlow,
        ::Ai::Tools::WhatsappAiAssistant::OfferProposalSupport,
        ::Ai::Tools::WhatsappAiAssistant::SupportProposal,
        ::Ai::Tools::WhatsappAiAssistant::CommentOnProposal,
        ::Ai::Tools::WhatsappAiAssistant::ManageSubscription,
        ::Ai::Tools::WhatsappAiAssistant::OpenNotificationSettings,
        ::Ai::Tools::WhatsappAiAssistant::StartUnlink,
        ::Ai::Tools::WhatsappAiAssistant::StopMessages,
        ::Ai::Tools::WhatsappAiAssistant::ShowHelp,
        ::Ai::Tools::WhatsappAiAssistant::ShowMainMenu,
        ::Ai::Tools::WhatsappAiAssistant::ClarifyIntent,
        ::Ai::Tools::WhatsappAiAssistant::RefuseOutOfScope,
        ::Ai::Tools::WhatsappAiAssistant::ReplyWithButtons
      ].map { |tool_class| tool_class.new(conversation: @conversation) } + [hand_to_flow]
    end

    # Held rather than built inline: whether it ran is the only way the caller
    # learns that this message belongs to the deterministic flow.
    def hand_to_flow
      @hand_to_flow ||=
        ::Ai::Tools::WhatsappAiAssistant::HandToFlow.new(conversation: @conversation)
    end

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] assistant routing failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: @conversation.id })
    end
end
