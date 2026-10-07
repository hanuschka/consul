require "rails_helper"

describe OpenaiApi::ToolLoop do
  # The guarantee one draft change rests on to produce one preview: once a tool has
  # answered the citizen itself, the other calls of the same response are answered
  # rather than run. ruby_llm 1.x ran every call of a batch after a halt, and a
  # preview and a second answering tool from one response reached the citizen as
  # two previews a few seconds apart.
  def function_call(name, call_id)
    double(:function_call, function_call?: true, name: name, arguments: "{}", call_id: call_id)
  end

  let(:preview_tool) { double(:preview_tool, name: "show_draft_for_confirmation") }
  let(:reply_tool) { double(:reply_tool, name: "reply_with_actions") }

  let(:response) do
    double(
      :response,
      id: "resp_1",
      output: [
        function_call("show_draft_for_confirmation", "call_1"),
        function_call("reply_with_actions", "call_2")
      ]
    )
  end

  let(:tool_loop) do
    OpenaiApi::ToolLoop.new(
      tools: [preview_tool, reply_tool],
      tool_definitions: [],
      model: "model",
      instructions: "instructions",
      input: [],
      feature: AiUsageRecord::UNKNOWN_FEATURE,
      timeout_seconds: 30
    )
  end

  before do
    allow(OpenaiApi::Responses).to receive(:create).and_return(response)
    allow(preview_tool).to receive(:call).and_return(ToolHalt.new("Showed them the draft."))
    allow(reply_tool).to receive(:call)
  end

  it "ends the turn on the halt" do
    expect(tool_loop.call).to be_halted
  end

  it "does not run a second answering tool from the same response" do
    tool_loop.call

    expect(reply_tool).not_to have_received(:call)
  end

  it "answers the call it skipped, so the chain stays valid" do
    outputs = tool_loop.call.pending_tool_outputs

    expect(outputs.last).to include(call_id: "call_2", output: OpenaiApi::ToolLoop::SKIPPED_OUTPUT)
  end

  it "asks the model nothing more in that turn" do
    tool_loop.call

    expect(OpenaiApi::Responses).to have_received(:create).once
  end
end
