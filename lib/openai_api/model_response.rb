# One response from the Responses API, with a reader for each field the app
# reads and nothing else. Written out rather than derived from the body, so a
# field this client does not know about is a NoMethodError at the call site
# instead of a nil that travels.
#
# `output_text` is the reason a wrapper is needed at all: the provider does
# not send it. It sends `output` as a list of items — reasoning, messages,
# function calls — and the text of an answer lives in the content parts of the
# message items. The official SDK folded those into a single string and every
# caller here reads that string, so the folding is done here.
class OpenaiApi::ModelResponse
  def initialize(body)
    @body = body
  end

  def id
    @body["id"]
  end

  def model
    @body["model"]
  end

  def output
    @output ||= Array(@body["output"]).map { |item| ::OpenaiApi::OutputItem.new(item) }
  end

  # Absent on a response the provider refused to finish, and the caller that
  # records it is the one that tolerates that.
  def usage
    return nil if @body["usage"].blank?

    @usage ||= ::OpenaiApi::TokenUsage.new(@body["usage"])
  end

  def output_text
    output.select(&:message?).flat_map(&:text_parts).join
  end
end
