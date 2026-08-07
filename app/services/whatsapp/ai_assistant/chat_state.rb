class Whatsapp::AiAssistant::ChatState
  # Every inbound message is its own job, so nothing about a ruby_llm chat
  # survives between two turns of the same conversation unless it is written
  # down. What is written down is the provider's own message shape — role,
  # text, tool calls, tool results — because replaying a summary instead lets
  # the model be talked into repeating a tool call it already made.
  CONTEXT_KEY = "ai_chat".freeze

  # Bounded here rather than by the retention job: that one purges
  # Whatsapp::Message rows and never looks at this column.
  MAX_MESSAGES = 24

  def initialize(conversation:)
    @conversation = conversation
  end

  def replay_into(chat)
    stored_messages.each { |stored_message| chat.add_message(attributes_from(stored_message)) }

    chat
  end

  def save!(chat)
    @conversation.merge_context!(CONTEXT_KEY => dump(chat.messages))
  end

  private

    def stored_messages
      Array(@conversation.context[CONTEXT_KEY])
    end

    # The system message is left out on purpose: it is rebuilt from live state
    # every turn, so a stored copy would only ever be the stale one.
    def dump(messages)
      trimmed(messages.reject { |message| message.role == :system }).map do |message|
        {
          "role" => message.role.to_s,
          "content" => text_of(message.content),
          "tool_calls" => dump_tool_calls(message.tool_calls),
          "tool_call_id" => message.tool_call_id
        }.compact
      end
    end

    def dump_tool_calls(tool_calls)
      return if tool_calls.blank?

      tool_calls.transform_values(&:to_h).deep_stringify_keys
    end

    # A tool result whose tool call was cut away is rejected by the provider, so
    # the window cannot start just anywhere: it starts where a turn starts, at
    # the oldest user message still inside it.
    def trimmed(messages)
      return messages if messages.length <= MAX_MESSAGES

      first_kept = messages.length - MAX_MESSAGES
      boundary = (first_kept...messages.length).find { |index| messages[index].role == :user }

      return [] if boundary.nil?

      messages[boundary..]
    end

    def text_of(content)
      return content if content.is_a?(String)
      return content.text.to_s if content.respond_to?(:text)

      content.to_s
    end

    def attributes_from(stored_message)
      {
        role: stored_message["role"].to_sym,
        content: stored_message["content"].to_s,
        tool_calls: tool_calls_from(stored_message["tool_calls"]),
        tool_call_id: stored_message["tool_call_id"]
      }.compact
    end

    def tool_calls_from(stored_tool_calls)
      return if stored_tool_calls.blank?

      stored_tool_calls.to_h do |id, attributes|
        [
          id,
          ::RubyLLM::ToolCall.new(
            id: attributes["id"],
            name: attributes["name"],
            arguments: attributes["arguments"] || {}
          )
        ]
      end
    end
end
