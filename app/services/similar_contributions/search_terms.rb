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

  def strip_html(value)
    ActionController::Base.helpers.sanitize(value.to_s, tags: [])
  end
end
