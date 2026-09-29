module Ai::StructuredOutput
  # ruby_llm 2 hands a schema-bound reply back as the JSON text it arrived as and
  # parses it only when asked, where 1.x parsed it into `content` and left the text
  # there when it did not parse. Every caller here was written against the second,
  # so this is that contract in one place: the Hash when the reply is JSON, and the
  # reply itself when it is not — which is what a caller checking `is_a?(Hash)`
  # goes on relying on to tell the two apart.
  module_function

  def content_of(response)
    response.parsed || response.content
  rescue JSON::ParserError
    response.content
  end
end
