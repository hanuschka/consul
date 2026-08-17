# The numbered list of title image choices offered in the chat: every picture
# found in the uploaded documents, then "create one with AI" and "no title image".
#
# One list, two consumers — the picker message renders it and a typed reply is
# resolved against it — so the number the admin reads is the number the parser
# looks up. Building the numbering in either place separately is how "3" would
# come to mean different things in the message and in the reply.
module ProjektImports::TitleImageOptions
  Option = Struct.new(:number, :mode, :index, :candidate, keyword_init: true) do
    def document?
      mode == "document"
    end

    def selectable?
      return candidate.eligible if document?

      true
    end
  end

  def self.for(projekt_import)
    image_options =
      projekt_import.source_image_candidates.map.with_index(1) do |candidate, number|
        Option.new(number: number, mode: "document", index: candidate.index, candidate: candidate)
      end

    image_options + [
      Option.new(number: image_options.size + 1, mode: "generated"),
      Option.new(number: image_options.size + 2, mode: "none")
    ]
  end

  # A reply counts as a pick only when the whole message is that number, with at
  # most a "Bild"/"Image"/"Nr." in front of it. A sentence that merely contains a
  # digit is left to the assistant.
  #
  # A bare number can still be meant as an answer to one of the assistant's
  # numbered questions; the confirmation message says which image was taken, so a
  # wrong reading is visible immediately and one click from being corrected.
  NUMBER_REPLY = /\A(?:bild|image|nr\.?|no\.?|#)?\s*#?\s*(\d{1,2})[.)]?\z/i

  def self.from_message(projekt_import, content)
    match = content.to_s.strip.match(NUMBER_REPLY)
    return nil if match.nil?

    self.for(projekt_import).find { |option| option.number == match[1].to_i }
  end
end
