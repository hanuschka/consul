# One item of a response's output. The list mixes kinds — a reasoning summary,
# a message the model wrote, a function it wants called — so the kind is asked
# for with a predicate and the fields of the other kinds are simply nil.
class OpenaiApi::OutputItem
  MESSAGE = "message".freeze
  FUNCTION_CALL = "function_call".freeze
  OUTPUT_TEXT = "output_text".freeze

  def initialize(item)
    @item = item
  end

  def type
    @item["type"]
  end

  def message?
    type == MESSAGE
  end

  def function_call?
    type == FUNCTION_CALL
  end

  def name
    @item["name"]
  end

  # JSON in a string, as the provider sends it. Parsed by the tool loop, which
  # is where an unparseable one has an answer to give the model.
  def arguments
    @item["arguments"]
  end

  # The id a function call's output has to be sent back under. Not the item's
  # own id, which is a different value the provider also sends.
  def call_id
    @item["call_id"]
  end

  def text_parts
    Array(@item["content"])
      .select { |part| part["type"] == OUTPUT_TEXT }
      .map { |part| part["text"] }
  end
end
