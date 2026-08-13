module TextSimilarity
  # Trigram overlap between two short strings, on Postgres pg_trgm's definition:
  # each word is padded with two leading and one trailing space, cut into
  # three-character slices, and the two sets are compared as shared over union.
  #
  # Done in Ruby rather than through the extension because the strings it is
  # asked about are not columns. A projekt's title comes from
  # Whatsapp::ProjektLink, which reads a translated page, so there is nothing for
  # SQL to index and the candidate set is already loaded by the time the question
  # is asked.
  #
  # Accents are folded before comparison, so a citizen who writes "Grunflache"
  # for "Grünfläche" is not answered with "no such projekt" over two umlauts.
  PADDING = "  ".freeze
  TRIGRAM_LENGTH = 3

  module_function

  # 1.0 for identical strings, 0.0 for nothing in common. Two blank strings
  # score 0 rather than 1: nothing is not a match for nothing, and the callers
  # ask this about user input.
  def trigram_score(left, right)
    left_trigrams = trigrams(left)
    right_trigrams = trigrams(right)

    return 0.0 if left_trigrams.empty? || right_trigrams.empty?

    shared = (left_trigrams & right_trigrams).size
    union = (left_trigrams | right_trigrams).size

    shared.fdiv(union)
  end

  def trigrams(text)
    normalize(text).split.flat_map { |word| word_trigrams(word) }.uniq
  end

  def normalize(text)
    I18n.transliterate(text.to_s.unicode_normalize(:nfc))
      .downcase
      .gsub(/[^a-z0-9]+/, " ")
      .strip
  end

  def word_trigrams(word)
    padded = "#{PADDING}#{word} "

    (0..padded.length - TRIGRAM_LENGTH).map { |offset| padded[offset, TRIGRAM_LENGTH] }
  end
end
