module Ai::OutputLanguage
  LANGUAGE_NAMES = {
    "de" => "German",
    "en" => "English"
  }.freeze

  FALLBACK = "German".freeze

  # A content block's locale column is only the row it is stored in, never a
  # claim about the language of its text, so the language the model writes in
  # is a separate decision. On a live site the site's own language is the only
  # correct answer. In development it follows the editor instead, so both
  # German and English copy can be produced locally without the text ending up
  # in a row nothing reads.
  def self.name_for(locale)
    return FALLBACK if !Rails.env.development?

    LANGUAGE_NAMES.fetch(locale.to_s, FALLBACK)
  end
end
