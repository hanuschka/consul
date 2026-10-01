# What a tool returns when it has already answered the user itself — sent the
# message, shown the preview — so the model must not be asked to write a reply
# on top of it. `content` is what the model is told happened, and it is what
# lands in the conversation as the tool's result.
#
# ruby_llm used to carry this as RubyLLM::Tool::Halt and stop its own loop on
# it. It no longer does: the caller decides when a turn is over. So the signal
# is owned here, and each loop that runs tools — ruby_llm's, driven through
# tool approvals, and OpenaiApi::ToolLoop — reads it the same way.
ToolHalt = Struct.new(:content) do
  def to_s
    content.to_s
  end
end
