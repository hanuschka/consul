module Whatsapp::MessageBlock
  # The mechanics behind every block the bot composes from a record rather than
  # letting the model write: a draft awaiting confirmation, a comment awaiting
  # confirmation, a contribution or a support that has just gone in.
  #
  # All four are the same shape and none of the shape is interesting on its own —
  # the citizen's own words untouched, a group of labelled lines saying where they
  # are going, and sometimes a closing line with an address in it. What is worth
  # writing once is the four rules the shape has to keep, because each of them is
  # a way for two renderers to drift apart and none of them is visible in a
  # diff:
  #
  # - The citizen's text is never translated and never truncated. It is theirs and
  #   it is already in their language; a renderer that shortens it defeats the
  #   whole point of composing the block in Ruby.
  # - The fixed labels are translated in one batch. Two calls mean two cache
  #   states, and a block arriving half in German reads as a fault rather than as
  #   a contribution.
  # - A block too long for one message is split, never cut.
  # - What was shown is digested from the values, not from the rendered text —
  #   labels come back from a translation cache, so the same record would digest
  #   differently depending on whether a line had been seen before.

  PARAGRAPH_BREAK = "\n\n".freeze

  LINE_BREAK = "\n".freeze

  # Between the values a digest is taken over, so that ["ab", "c"] and ["a", "bc"]
  # are not the same draft. A character no portal text can contain.
  DIGEST_SEPARATOR = "\x1f".freeze

  module_function

  # The fixed lines of one block, in the citizen's language, keyed as they were
  # asked for. One call for all of them, and the copy as written whenever the
  # translation is unavailable — BotCopyService answers with its own input on every
  # failure path, so there is nothing to rescue here and no label can arrive blank.
  def labels(account:, scope:, keys:)
    written = keys.index_with { |key| I18n.t("#{scope}.#{key}") }

    keys.zip(::Whatsapp::AiAssistant::BotCopyService.call(account: account, lines: written.values))
        .to_h
  end

  # The sections of a block, separated so each reads as its own thing. Blank
  # sections drop out rather than leaving a gap: what a block carries depends on
  # what the record holds.
  def compose(sections)
    Array(sections).compact_blank.join(PARAGRAPH_BREAK).presence
  end

  # One group of "Label: value" lines, kept together on single breaks so the group
  # reads as a group. A pair whose value is missing is not a line — a phase that
  # collects no pictures should say nothing about pictures.
  def labelled_lines(pairs)
    Array(pairs)
      .reject { |_label, value| value.blank? }
      .map { |label, value| "#{label}: #{value}" }
      .join(LINE_BREAK)
      .presence
  end

  # A block longer than one message, split rather than cut: the one thing these
  # blocks exist to guarantee is that nothing the citizen reads has been
  # shortened. Paragraph boundaries first, because they are where the block's
  # own structure is.
  #
  # The limit is a parameter because a text message and an interactive one hold
  # different amounts and both are split the same way. It defaults to the text
  # message's, which is what every block caller wants.
  def chunks(block, limit: ::Whatsapp::MAX_TEXT_BODY_LENGTH)
    return [block] if block.to_s.length <= limit

    block
      .split(PARAGRAPH_BREAK)
      .flat_map { |paragraph| hard_slices(paragraph, limit) }
      .each_with_object([]) { |paragraph, collected| append(collected, paragraph, limit) }
  end

  # What was shown, reduced to the values behind it. Stored when a block is sent
  # and re-checked before the irreversible thing it asked about, so a record
  # changed after the question was asked cannot be acted on with the old answer.
  def digest(values)
    Digest::SHA256.hexdigest(Array(values).join(DIGEST_SEPARATOR))
  end

  # Portal markup flattened the one way the bot flattens it, and with the length of
  # the markup as the cut — always longer than the text inside it, so nothing is
  # ever truncated.
  def verbatim(html)
    text = html.to_s

    ::Whatsapp.plain_text(text, length: text.length + 1).presence
  end

  def hard_slices(paragraph, limit)
    return [paragraph] if paragraph.length <= limit

    paragraph.scan(/.{1,#{limit}}/m)
  end

  def append(collected, paragraph, limit)
    previous = collected.last
    joined = [previous, paragraph].join(PARAGRAPH_BREAK)

    if previous.present? && joined.length <= limit
      collected[-1] = joined
    else
      collected << paragraph
    end
  end

  private_class_method :hard_slices, :append
end
