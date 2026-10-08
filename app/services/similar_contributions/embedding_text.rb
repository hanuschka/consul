module SimilarContributions::EmbeddingText
  MAX_LENGTH = 4000

  module_function

  def for(resource)
    body = SimilarContributions::SearchTerms.strip_html(resource.description).squish

    "#{resource.title}\n\n#{body}".strip.truncate(MAX_LENGTH)
  end

  def digest(text)
    Digest::SHA256.hexdigest(text)
  end
end
