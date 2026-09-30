# Shortens text to a character budget without cutting mid-sentence where it
# can help it: the cut falls on the last paragraph, line, or word break inside
# the budget, unless that break sits in the first half — then a hard cut keeps
# more of the text than a tidy boundary would.
module TextClipper
  def self.call(text, max_chars)
    return text if text.length <= max_chars

    clipped = text[0, max_chars]
    boundary = clipped.rindex("\n\n") || clipped.rindex("\n") || clipped.rindex(" ")

    return clipped if boundary.nil? || boundary <= max_chars / 2

    clipped[0, boundary]
  end
end
