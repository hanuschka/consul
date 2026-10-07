# Removes the characters a browser never shows but a model reads: zero-width
# joiners and spaces, bidi controls, the byte-order mark, and the Unicode Tag
# block (U+E0000–E007F) that spells ASCII invisibly. Normalisation alone does
# not remove Tag characters, and stripping once is not enough when a removed
# character exposes another, so the pass repeats until the text is stable.
module InvisibleUnicodeStripper
  SMUGGLED_CHARACTERS = /[\u200B-\u200F\u202A-\u202E\u2060-\u2064\u2066-\u2069\uFEFF\u{E0000}-\u{E007F}]/

  def self.call(text)
    cleaned = text.to_s.unicode_normalize(:nfc)
    removed = 0

    loop do
      stripped = cleaned.gsub(SMUGGLED_CHARACTERS, "")
      removed += cleaned.length - stripped.length
      break if stripped == cleaned

      cleaned = stripped
    end

    { text: cleaned, removed_characters: removed }
  end
end
