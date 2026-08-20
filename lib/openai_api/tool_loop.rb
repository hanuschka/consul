# The loop ruby_llm used to own: ask, run whatever tools the model called, hand
# the results back, ask again, until it answers in words or a tool answers for
# it. The tools themselves are still RubyLLM::Tool subclasses — this only
# replaces the transport around them, so their schemas, argument validation and
# halt contract are unchanged.
class OpenaiApi::ToolLoop
  # How one turn ended. `halt` carries the RubyLLM::Tool::Halt a tool returns
  # when it has already spoken to the citizen itself, so a caller tells the two
  # endings apart exactly as it did before.
  #
  # `pending_tool_outputs` is what a halted turn leaves owing. The provider
  # rejects a chain whose last response has a function call nobody answered, so
  # those items travel with the stored chain and are sent at the head of the
  # next turn's input — which also tells the model what was already done rather
  # than leaving it to infer that from the arguments.
  Turn = Struct.new(:text, :halt, :response_id, :pending_tool_outputs, keyword_init: true) do
    def halted?
      halt.present?
    end
  end

  # A model that keeps calling tools without ever answering would hold the
  # conversation lock for as long as it kept going. The router's own counter
  # stops it first and with a better message; this is the backstop for a caller
  # that passes no counter at all.
  MAX_ITERATIONS = 12

  FUNCTION_CALL_OUTPUT = "function_call_output".freeze

  # Every call in a batch owes the provider an output, so the ones after a halt
  # are answered rather than dropped — but they are not run: the citizen has
  # been written to already, and a second tool sending them a second message is
  # the failure this avoids.
  SKIPPED_OUTPUT = "not run: an earlier tool in the same turn had already answered " \
                   "the citizen".freeze

  class RunawayError < StandardError; end

  def initialize(
    tools:, model:, instructions:, input:, feature:, timeout_seconds:,
    previous_response_id: nil, reasoning_effort: nil, &on_tool_call
  )
    @tools_by_name = tools.index_by(&:name)
    @tool_definitions = ::OpenaiApi::ToolDefinitions.build(tools)
    @model = model
    @instructions = instructions
    @input = input
    @feature = feature
    @timeout_seconds = timeout_seconds
    @previous_response_id = previous_response_id
    @reasoning_effort = reasoning_effort
    @on_tool_call = on_tool_call
    @halt = nil
  end

  def call
    input = @input
    iterations = 0

    loop do
      iterations += 1
      guard_runaway!(iterations)

      response = request(input)
      @previous_response_id = response.id
      function_calls = function_calls_in(response)

      return answered(response) if function_calls.empty?

      outputs = dispatch(function_calls)

      return halted(response, outputs) if @halt.present?

      input = outputs
    end
  end

  private

    def guard_runaway!(iterations)
      return if iterations <= MAX_ITERATIONS

      raise RunawayError, "the tool loop ran #{MAX_ITERATIONS} times without an answer"
    end

    # The instructions and the tools go up on every request rather than being
    # left to the chain: they are rebuilt from live conversation state each turn,
    # and the provider scopes them to the one response anyway.
    def request(input)
      ::OpenaiApi::Responses.create(
        feature: @feature,
        requested_model: @model,
        timeout_seconds: @timeout_seconds,
        model: @model,
        instructions: @instructions,
        input: input,
        tools: @tool_definitions,
        previous_response_id: @previous_response_id,
        store: true,
        reasoning: reasoning
      )
    end

    def reasoning
      return nil if @reasoning_effort.blank?

      { effort: @reasoning_effort }
    end

    def function_calls_in(response)
      response.output.select(&:function_call?)
    end

    # Sets @halt rather than returning it, because the outputs still have to be
    # built for the rest of the batch once one tool has halted.
    def dispatch(function_calls)
      function_calls.map do |function_call|
        if @halt.present?
          skipped_output(function_call)
        else
          run(function_call)
        end
      end
    end

    def run(function_call)
      @on_tool_call&.call(function_call)

      result = execute(function_call)

      if result.is_a?(::RubyLLM::Tool::Halt)
        @halt = result
      end

      output_for(function_call, result)
    end

    # Dispatched through the tool's own #call, so the argument normalisation and
    # the keyword validation that used to sit between the model and #execute are
    # still there — including the invalid-arguments error it hands back to the
    # model instead of raising.
    def execute(function_call)
      tool = @tools_by_name[function_call.name]

      return unknown_tool_error(function_call) if tool.blank?

      tool.call(arguments_of(function_call))
    end

    def arguments_of(function_call)
      JSON.parse(function_call.arguments.to_s.presence || "{}")
    rescue JSON::ParserError
      {}
    end

    def unknown_tool_error(function_call)
      { error: "There is no tool called #{function_call.name}." }
    end

    def output_for(function_call, result)
      {
        type: FUNCTION_CALL_OUTPUT,
        call_id: function_call.call_id,
        output: serialized(result)
      }
    end

    def skipped_output(function_call)
      {
        type: FUNCTION_CALL_OUTPUT,
        call_id: function_call.call_id,
        output: SKIPPED_OUTPUT
      }
    end

    def serialized(result)
      return result.to_s if result.is_a?(::RubyLLM::Tool::Halt)
      return result if result.is_a?(String)

      JSON.generate(result)
    end

    def answered(response)
      Turn.new(
        text: response.output_text.to_s,
        response_id: response.id,
        pending_tool_outputs: []
      )
    end

    def halted(response, outputs)
      Turn.new(
        halt: @halt,
        response_id: response.id,
        pending_tool_outputs: outputs
      )
    end
end
