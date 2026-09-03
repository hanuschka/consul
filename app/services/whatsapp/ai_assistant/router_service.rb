class Whatsapp::AiAssistant::RouterService < ApplicationService
  # Raised rather than returned: a model that keeps reading without ever
  # answering would hold the conversation lock and spend the budget for as long
  # as it kept going, and the caller's fallback is a better reply than none.
  class ToolLoopError < StandardError; end

  # The provider default is 300 seconds, written for a generation nobody waits
  # on. This one is waited on by a held advisory lock.
  REQUEST_TIMEOUT_SECONDS = 30

  # A question answered properly often costs several reads — what is open, what that
  # projekt is about, what came of it — and a submission step costs a read, a write
  # and the message that reports it. This is a runaway guard rather than a budget:
  # set tight enough to bite, it raises on the thorough answers instead of the
  # runaway ones.
  MAX_TOOL_CALLS = 12

  BLANK_MESSAGE_ERROR = "nothing to route".freeze

  EMPTY_ANSWER_ERROR = "assistant produced no reply".freeze

  # Deliberately says what to do and not why: it is stored in the conversation like
  # any other line, so the next turn reads it too, and a paragraph of reasoning here
  # would be a paragraph the model re-reads on every message for the rest of the
  # conversation.
  RETRY_FOR_ACTIONS = "That reply had nothing for the citizen to tap. Send it again with " \
                      "reply_with_actions — the same answer, plus the one or two things that " \
                      "can plausibly happen next from here. If there is genuinely no next " \
                      "step, answer in plain text again.".freeze

  # One turn, whichever transport answered it. `chat` is set on the ruby_llm
  # path and `chain_turn` on the Responses one, and the state writer picks by
  # which of the two it was handed — everything between the request and the
  # reply is shared.
  Turn = Struct.new(:halt, :text, :chat, :chain_turn, keyword_init: true) do
    def halted?
      halt.present?
    end
  end

  # `previous_inbound_at` is only passed through to the prompt, where it becomes the
  # one thing this turn cannot measure for itself: how long the citizen has been
  # away. The inbound chain overwrites the conversation's clock before anything can
  # read it, so it has to travel.
  def initialize(
    conversation:, inbound_text:, inbound_message_id: nil, previous_inbound_at: nil
  )
    @conversation = conversation
    @inbound_text = inbound_text
    @inbound_message_id = inbound_message_id
    @previous_inbound_at = previous_inbound_at
    @tool_calls_made = 0
  end

  def call
    return ServiceResult.failure(error: BLANK_MESSAGE_ERROR) if @inbound_text.blank?

    turn = ask
    outcome = deliver(turn)

    # Written down only for a turn that answered. A blank reply is a failure the
    # caller retries with the same words, and persisting it first would have the
    # retry asking on top of the inbound and the empty answer it is replacing —
    # which is why the rescue below returns without persisting either.
    return ServiceResult.failure(error: EMPTY_ANSWER_ERROR) if outcome == :empty

    persist(turn)

    ServiceResult.success(outcome: outcome)
  rescue StandardError => e
    report(e)

    ServiceResult.failure(error: e.message)
  end

  private

    # Which transport answers is a setting, so that a turn that goes wrong on the
    # newer one is a setting away from the older rather than a deploy away.
    def ask
      return openai_api_turn if profile.responses?

      ruby_llm_turn
    end

    # Read once per turn so the transport that answers, the model it is asked
    # for and the effort it is asked with cannot disagree with each other
    # mid-conversation when the settings change under a running worker.
    def profile
      @profile ||= ::Ai::ModelProfile.fast
    end

    def ruby_llm_turn
      chat = build_chat
      response = chat.ask(@inbound_text)

      return Turn.new(halt: response, chat: chat) if response.is_a?(::RubyLLM::Tool::Halt)

      Turn.new(text: response.content.to_s, chat: chat)
    end

    def build_chat
      chat = ::Ai::RubyLlmFactory.chat_for(
        profile, request_timeout: REQUEST_TIMEOUT_SECONDS, tools: tools
      )

      chat.with_instructions(instructions)
      chat.on_tool_call { |tool_call| track_tool_call(tool_call) }

      state.replay_into(chat)
    end

    def openai_api_turn
      loop_turn = run_tool_loop_with_stale_retry

      Turn.new(halt: loop_turn.halt, text: loop_turn.text, chain_turn: loop_turn)
    end

    # A chain the provider has forgotten — a conversation nobody has written to
    # since it fell out of their retention — is worth exactly one more attempt, on
    # a fresh chain. Anything else is a real failure and belongs to the caller's
    # rescue, which answers the citizen out of the deterministic flow.
    def run_tool_loop_with_stale_retry
      run_tool_loop
    rescue StandardError => e
      if !::Whatsapp::AiAssistant::ChatChain.stale?(e)
        raise
      end

      chain.clear!

      run_tool_loop
    end

    # The tools, the instructions and the runaway counter are the ones the
    # ruby_llm path uses: only the transport around them changes, so a misroute
    # reads the same in DecisionLog whichever one answered.
    def run_tool_loop
      tool_loop = ::OpenaiApi::ToolLoop.new(
        tools: tools,
        tool_definitions: tool_definitions,
        model: profile.model,
        instructions: instructions,
        input: chain.input_for(@inbound_text),
        feature: ::AiUsageRecord::UNKNOWN_FEATURE,
        timeout_seconds: REQUEST_TIMEOUT_SECONDS,
        previous_response_id: chain.previous_response_id,
        reasoning_effort: profile.reasoning_effort
      ) { |function_call| track_tool_call(function_call) }

      tool_loop.call
    end

    def instructions
      @instructions ||= ::Whatsapp::AiAssistant::SystemPromptService.call(
        conversation: @conversation,
        previous_inbound_at: @previous_inbound_at,
        inbound_message_id: @inbound_message_id
      )
    end

    # Logged per call because which tool the model picked is the only way to see a
    # misroute after the fact: the citizen's reply looks reasonable either way, and
    # nothing else records that "show me the projekts" ended in the menu. On
    # DecisionLog's tag with every other assistant decision, so one grep over a
    # day's logs reads as one table.
    def track_tool_call(tool_call)
      @tool_calls_made += 1

      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :tool_called, conversation: @conversation, tool: tool_call.name,
        step: @conversation.step
      )

      keep_waiting_visible

      @last_tool_name = tool_call.name

      return if @tool_calls_made <= MAX_TOOL_CALLS

      raise ToolLoopError, "assistant called more than #{MAX_TOOL_CALLS} tools in one turn"
    end

    # Asked again on every tool call, because both things that end the bubble happen
    # inside the loop: a tool that speaks to the citizen dismisses it, and a turn
    # still running after TYPING_INDICATOR_SECONDS has had it expire. Unthrottled on
    # purpose — MAX_TOOL_CALLS bounds it, and `typing` swallows its own failures, so
    # the cost of asking once too often is a log line the citizen never sees.
    def keep_waiting_visible
      ::Whatsapp::Send.typing(message_id: @inbound_message_id)
    end

    # The step column's whole remaining job: a diagnostic saying what the conversation
    # was doing, written from the last tool that ran rather than read by anything.
    # Stamped after the turn so a tool loop that raised leaves the step it reached
    # rather than the one it was heading for.
    def record_diagnostic_step
      return if @last_tool_name.blank?

      tool = tools_by_name[@last_tool_name]

      @conversation.record_step!(tool&.diagnostic_step)
    end

    def tools_by_name
      @tools_by_name ||= tools.index_by(&:name)
    end

    # Every tool that speaks to the citizen halts the loop, so reaching a plain
    # message here means nothing has been sent yet and the model's own text is the
    # whole reply.
    def deliver(turn)
      return :tool if turn.halted?

      body = turn.text.to_s.strip

      return :empty if body.blank?

      retried = retry_for_actions(turn)

      return :tool if retried == :sent

      # The retry's own answer when it produced one, never the first. Both are in the
      # stored history by then, and sending the earlier one would leave the last thing
      # the history says the bot said as something the citizen was never shown — which
      # the next turn reads back as fact.
      body = retried.presence || body

      record_missed_actions

      # Through buttons rather than text, even with nothing of its own to offer:
      # Whatsapp::Send puts the main menu on every interactive message, so this is
      # what makes "every reply has something to tap" true of the one path that
      # composes no buttons at all.
      ::Whatsapp::Send.buttons(
        account: @conversation.whatsapp_account, body: body, buttons: []
      )

      :answered
    end

    # Handed its own answer back and asked to send it again with the buttons on it.
    # One more request, because which two options fit this moment is the one thing
    # only the model knows, and a reply the citizen can read but not act on is the
    # whole of what this work is about. A tool call is the success signal:
    # reply_with_actions halts the turn, so a halt here means the message went out
    # tappable and the plain text above was never sent.
    #
    # Only on the transport that can continue a turn in place. `chat` is the same
    # object the answer came from, so re-asking costs one request and keeps the
    # history. The Responses chain advances only when this turn is persisted, which
    # happens after delivery — re-entering the tool loop before that would have the
    # retry answering from a state that does not exist yet. There it falls through to
    # the send above, which still carries the main menu.
    #
    # The halt is written back onto the turn so persistence sees it: the state writer
    # records a halted turn's note, and without this the retry's tool call would be
    # stored as a turn that answered with nothing.
    # :sent when the retry put a tappable message out itself, the retry's own text
    # when it answered in words again, nil when there was no retry to make. The three
    # are distinguished because only the first means the citizen has been answered.
    def retry_for_actions(turn)
      return if turn.chat.blank?
      return if @tool_calls_made >= MAX_TOOL_CALLS

      response = turn.chat.ask(RETRY_FOR_ACTIONS)

      if response.is_a?(::RubyLLM::Tool::Halt)
        turn.halt = response

        return :sent
      end

      response.content.to_s.strip
    rescue StandardError => e
      report(e)

      nil
    end

    # Reaching here is a reply with nothing to tap: every tool that sends an
    # interactive message halts the turn, so plain text is the only thing this path
    # delivers. Some of those are right — a question that was not the bot's to
    # answer, a goodbye — which is why this counts rather than intervenes. What it
    # buys is the denominator: the same reply reads as a considered full stop and as
    # a citizen left working out what to write, and only the rate tells them apart.
    #
    # The last tool that ran is carried along because it is the one thing that says
    # whether options were on the table: a plain reply after a listing tool is a list
    # of names nobody can tap, while one after no tool at all is usually a
    # conversation ending.
    def record_missed_actions
      ::Whatsapp::AiAssistant::DecisionLog.record(
        event: :actions_missed,
        conversation: @conversation,
        after_tool: @last_tool_name,
        step: @conversation.step
      )
    end

    # Kept out of the turn's own rescue. By the time state is written the citizen
    # has already been answered, so reporting the turn as failed would have the
    # caller answer them a second time out of the deterministic flow — losing the
    # history is the far smaller failure.
    def persist(turn)
      save_state(turn)
      record_diagnostic_step
    rescue StandardError => e
      report(e)
    end

    # Each transport keeps its own kind of state and drops the other's, so which
    # one wrote last is never ambiguous.
    def save_state(turn)
      return chain.save!(turn.chain_turn) if turn.chain_turn.present?

      save_chat_state(turn)
    end

    # A halted turn ends on a tool result with nothing after it. The note keeps
    # the stored history in the shape every provider expects, and tells the next
    # turn what was already done rather than leaving it to guess from arguments.
    # The Responses transport owes the same thing, and pays it with the pending
    # tool outputs the chain carries instead.
    def save_chat_state(turn)
      if turn.halted?
        turn.chat.add_message(role: :assistant, content: turn.halt.to_s)
      end

      state.save!(turn.chat)
    end

    def state
      @state ||= ::Whatsapp::AiAssistant::ChatState.new(conversation: @conversation)
    end

    def chain
      @chain ||= ::Whatsapp::AiAssistant::ChatChain.new(conversation: @conversation)
    end

    # Built once per turn and reused, because the diagnostic step is read back off
    # the same instances after the turn — and because a tool that memoizes a query
    # should not throw it away between two calls of one turn.
    def tools
      @tools ||= tool_classes.map { |tool_class| tool_class.new(conversation: @conversation) }
    end

    # Built once a turn and only for the transport that needs them: the ruby_llm
    # path hands the tool objects straight to the chat, which describes them to
    # the provider itself.
    def tool_definitions
      @tool_definitions ||= ::RubyLlmToolToOpenAiConverter.definitions_for(tools)
    end

    # The tools that act on a Consul account, left out for a number that has none.
    # Everything else — every read, the browsing, and contributing to a phase that
    # allows guests — is offered to linked and unlinked alike, and linking is asked
    # for by whichever action turns out to need one.
    #
    # Opting out stays available to a guest on purpose. It is the one request that
    # must be answerable by anyone the bot has ever messaged.
    ACCOUNT_TOOLS = [
      ::Ai::Tools::WhatsappAiAssistant::MyFollowedProjekts,
      ::Ai::Tools::WhatsappAiAssistant::MyContributions,
      ::Ai::Tools::WhatsappAiAssistant::MyNotificationSettings,
      ::Ai::Tools::WhatsappAiAssistant::ToggleNotification,
      ::Ai::Tools::WhatsappAiAssistant::SupportProposal,
      ::Ai::Tools::WhatsappAiAssistant::DraftComment,
      ::Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation,
      ::Ai::Tools::WhatsappAiAssistant::PostComment,
      ::Ai::Tools::WhatsappAiAssistant::ManageSubscription,
      ::Ai::Tools::WhatsappAiAssistant::UnlinkAccount
    ].freeze

    # Withheld from a linked number, because it is the one tool whose whole subject
    # is not having an account: offered to someone who already has one it invites a
    # login link they do not need.
    LINKING_TOOLS = [::Ai::Tools::WhatsappAiAssistant::SendLoginLink].freeze

    def tool_classes
      return offerable_tools - LINKING_TOOLS if @conversation.whatsapp_account.user_id.present?

      offerable_tools - ACCOUNT_TOOLS
    end

    # ── The whole vocabulary ────────────────────────────────────────────────
    # Grouped by what earns a tool at all: reading state the model cannot know,
    # writing state, and sending a WhatsApp message type that is not text. Asking,
    # refusing, explaining and offering are absent from this list on purpose — they
    # are sentences, and a tool for a sentence is a worse version of one.
    def offerable_tools
      READ_TOOLS + WRITE_TOOLS + DRAFT_TOOLS + SEND_TOOLS
    end

    # Each returns facts and sends nothing.
    READ_TOOLS = [
      ::Ai::Tools::WhatsappAiAssistant::ListOpenProjekts,
      ::Ai::Tools::WhatsappAiAssistant::FindProjektsByTopic,
      ::Ai::Tools::WhatsappAiAssistant::ListOpenPhases,
      ::Ai::Tools::WhatsappAiAssistant::CheckParticipationEligibility,
      ::Ai::Tools::WhatsappAiAssistant::DescribeProjekt,
      ::Ai::Tools::WhatsappAiAssistant::ProjektConfiguration,
      ::Ai::Tools::WhatsappAiAssistant::ListProjektResults,
      ::Ai::Tools::WhatsappAiAssistant::ListMilestones,
      ::Ai::Tools::WhatsappAiAssistant::ListEvents,
      ::Ai::Tools::WhatsappAiAssistant::ListOpenPolls,
      ::Ai::Tools::WhatsappAiAssistant::ListProjektContributions,
      ::Ai::Tools::WhatsappAiAssistant::FindContribution,
      ::Ai::Tools::WhatsappAiAssistant::MyFollowedProjekts,
      ::Ai::Tools::WhatsappAiAssistant::MyContributions,
      ::Ai::Tools::WhatsappAiAssistant::MyNotificationSettings
    ].freeze

    # Each mutates something and owns the preconditions for doing so.
    WRITE_TOOLS = [
      ::Ai::Tools::WhatsappAiAssistant::SupportProposal,
      ::Ai::Tools::WhatsappAiAssistant::DraftComment,
      ::Ai::Tools::WhatsappAiAssistant::PostComment,
      ::Ai::Tools::WhatsappAiAssistant::ManageSubscription,
      ::Ai::Tools::WhatsappAiAssistant::ToggleNotification,
      ::Ai::Tools::WhatsappAiAssistant::SendLoginLink,
      ::Ai::Tools::WhatsappAiAssistant::UnlinkAccount,
      ::Ai::Tools::WhatsappAiAssistant::StopMessages
    ].freeze

    # The submission, which used to be a machine of twenty-two steps. What was the
    # sequence's guarantee is each tool's own precondition now — consent, the phase
    # still being open, the draft being complete — because the order is the
    # assistant's to choose and a rule it is merely told is a rule it can talk
    # itself past.
    DRAFT_TOOLS = [
      ::Ai::Tools::WhatsappAiAssistant::RecordTermsConsent,
      ::Ai::Tools::WhatsappAiAssistant::StartDraft,
      ::Ai::Tools::WhatsappAiAssistant::DraftStatus,
      ::Ai::Tools::WhatsappAiAssistant::DraftProposal,
      ::Ai::Tools::WhatsappAiAssistant::ReviseDraft,
      ::Ai::Tools::WhatsappAiAssistant::SetDraftCategory,
      ::Ai::Tools::WhatsappAiAssistant::SetDraftSentiment,
      ::Ai::Tools::WhatsappAiAssistant::AttachDraftImage,
      ::Ai::Tools::WhatsappAiAssistant::GenerateDraftImage,
      ::Ai::Tools::WhatsappAiAssistant::SetDraftLocation,
      ::Ai::Tools::WhatsappAiAssistant::PublishDraft,
      ::Ai::Tools::WhatsappAiAssistant::AbortSubmission
    ].freeze

    # What plain text cannot express: the four interactive message types, and the one
    # ordinary sentence that must carry a legal notice with it. A plain-text reply
    # needs no tool at all — this service sends the model's own words when it calls
    # nothing.
    SEND_TOOLS = [
      ::Ai::Tools::WhatsappAiAssistant::ReplyWithActions,
      ::Ai::Tools::WhatsappAiAssistant::SendList,
      ::Ai::Tools::WhatsappAiAssistant::SendLink,
      ::Ai::Tools::WhatsappAiAssistant::SendProjektCard,
      ::Ai::Tools::WhatsappAiAssistant::ShowDraftForConfirmation,
      ::Ai::Tools::WhatsappAiAssistant::ShowCommentForConfirmation,
      ::Ai::Tools::WhatsappAiAssistant::RequestLocation,
      ::Ai::Tools::WhatsappAiAssistant::RequestPhoto
    ].freeze

    def report(exception)
      Rails.logger.error(
        "[Whatsapp] assistant routing failed: #{exception.class} - #{exception.message}"
      )

      Sentry.capture_exception(exception, extra: { whatsapp_conversation_id: @conversation.id })
    end
end
