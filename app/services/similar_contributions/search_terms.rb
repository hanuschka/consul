module SimilarContributions::SearchTerms
  MIN_TERM_LENGTH = 4
  MAX_TERMS = 40

  module_function

  def extract(title, description)
    words = "#{title} #{strip_html(description)}"
      .unicode_normalize(:nfkc)
      .downcase
      .gsub(/[^[[:alnum:]]\s]/, " ")
      .split

    words
      .select { |word| word.length >= MIN_TERM_LENGTH }
      .uniq
      .first(MAX_TERMS)
  end

  def query_string(title, description)
    extract(title, description).join(" ")
  end

  # Plain text, decoded: pruning drops script and style bodies with their
  # elements instead of flattening them into readable words, and asking the
  # fragment for its text -- rather than serialising it back to markup --
  # leaves &amp; and &lt; as the characters they stand for. A serialised string
  # still carries them encoded, and every caller here goes on to squish or
  # truncate it, which loses the html_safe flag and hands the entity to the
  # escaper a second time.
  def strip_html(value)
    fragment = Loofah.fragment(value.to_s)
    fragment.scrub!(:prune)
    fragment.text(encode_special_chars: false)
  end
end
