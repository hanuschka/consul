module MultilineSubtitleNormalizer
  module_function

  MAX_VISIBLE_LENGTH = 500
  MAX_LINE_BREAKS = 4

  INVISIBLE_CHARS_REGEX =
    /[\u{200B}-\u{200F}\u{202A}-\u{202E}\u{2060}-\u{206F}\u{FEFF}\u{180E}]/

  CONTROL_CHARS_REGEX =
    /[\u{0000}-\u{0008}\u{000B}-\u{001F}\u{007F}-\u{009F}]/

  NON_BREAKING_SPACE = "\u{00A0}".freeze

  BR_REGEX = /<br\s*\/?>/i

  # Block-level tags whose boundaries must be treated as line breaks. Browsers'
  # contenteditable Enter handling varies: Chromium often wraps lines in <div>,
  # Firefox in <p>, WebKit sometimes <p> too. Without this step, sanitize would
  # strip the tags and concatenate the text, silently dropping the line break.
  BLOCK_OPEN_TAG_REGEX = /<\s*(?:div|p|li|h[1-6]|article|section|blockquote|tr|pre)(?:\s[^>]*)?\s*\/?\s*>/i
  BLOCK_CLOSE_TAG_REGEX = /<\s*\/\s*(?:div|p|li|h[1-6]|article|section|blockquote|tr|pre)\s*>/i

  def normalize(input)
    return "" if input.blank?

    text = input.to_s.dup
    text = text.unicode_normalize(:nfc)
    text = text.gsub(BR_REGEX, "\n")
    text = text.gsub(BLOCK_OPEN_TAG_REGEX, "\n")
    text = text.gsub(BLOCK_CLOSE_TAG_REGEX, "")
    text = text.gsub(/\r\n|\r/, "\n")
    text = text.gsub(INVISIBLE_CHARS_REGEX, "")
    text = text.gsub(CONTROL_CHARS_REGEX, "")
    text = text.gsub(NON_BREAKING_SPACE, " ")
    text = text.split("\n").map { |line| line.gsub(/[ \t]+/, " ").strip }.join("\n")
    text = text.gsub(/\n{3,}/, "\n\n")
    text = text.strip

    text.gsub("\n", "<br>")
  end

  def visible_length(html_or_text)
    return 0 if html_or_text.blank?

    html_or_text.to_s.gsub(BR_REGEX, "").each_grapheme_cluster.count
  end

  def line_break_count(html_or_text)
    return 0 if html_or_text.blank?

    html_or_text.to_s.scan(BR_REGEX).count
  end
end
