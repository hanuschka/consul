# What one response was billed as. The provider reports cached input tokens and
# reasoning tokens nested a level down; they are read out flat here because the
# usage table stores them as four columns and nothing else needs the nesting.
class OpenaiApi::TokenUsage
  def initialize(usage)
    @usage = usage
  end

  def input_tokens
    @usage["input_tokens"]
  end

  def output_tokens
    @usage["output_tokens"]
  end

  def cached_tokens
    @usage.dig("input_tokens_details", "cached_tokens")
  end

  # Billed as output tokens and reported inside the output detail, so they are
  # passed on their own key rather than added to the total: the usage table
  # counts them separately.
  def reasoning_tokens
    @usage.dig("output_tokens_details", "reasoning_tokens")
  end
end
