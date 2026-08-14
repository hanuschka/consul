class Whatsapp::Inbound::MessageReading
  # One object reads the inbound payload, so no collaborator digs into
  # raw_message on its own or transcribes the same voice note twice: the
  # memoized text — including a memoized nil for a failed transcript — is
  # the "transcribe at most once" guarantee.
  #
  # Deliberately a plain per-message object rather than a service: it is a
  # private organ of the inbound gate chain, handed to the dispatch
  # collaborators by the spine, never called from anywhere else.
  def initialize(whatsapp_message:, raw_message:)
    @whatsapp_message = whatsapp_message
    @raw_message = raw_message || {}
  end

  # A tapped row or button already says exactly what it means, and the text
  # WhatsApp sends alongside it is only that row's own label. Consumers read
  # the id; sending the label to the assistant instead would pay for a
  # completion to re-derive it, and risk a tapped "Yes, submit it" being
  # answered as conversation rather than publishing the draft.
  def tapped_reply_id
    list_reply_id.presence || button_reply_id.presence
  end

  def text
    return @text if defined?(@text)

    @text =
      if @whatsapp_message.audio?
        transcribed_text
      else
        @whatsapp_message.body
      end
  end

  def normalized_text
    @normalized_text ||= text.to_s.strip.downcase
  end

  # A voice note nothing could be read from. Asking forces the one
  # transcription attempt; the spine announces the failure to the citizen
  # (see announce_unreadable_voice_note there — the reply's position in the
  # gate chain is load-bearing).
  def unreadable_voice_note?
    audio? && text.blank?
  end

  # The coordinates as WhatsApp's picker sent them, alongside an optional name
  # and address the flow has no use for — the pin is what a map renders.
  def location
    @raw_message["location"]
  end

  def image_id
    @raw_message.dig("image", "id")
  end

  # The wamid of the message being answered. WhatsApp ties a typing indicator
  # to one inbound message, so the slow paths need it to show the bubble.
  def message_id
    @whatsapp_message.wa_message_id
  end

  def audio?
    @whatsapp_message.audio?
  end

  def welcome?
    @whatsapp_message.welcome?
  end

  def sent_at
    @whatsapp_message.sent_at
  end

  private

    def button_reply_id
      @raw_message.dig("interactive", "button_reply", "id") ||
        @raw_message.dig("button", "payload")
    end

    def list_reply_id
      @raw_message.dig("interactive", "list_reply", "id")
    end

    # What was read is recorded: the /adm dialog history shows the message
    # body, so a successful transcript replaces the empty audio body.
    def transcribed_text
      transcript = Whatsapp::Inbound::TranscribeVoiceService.call(
        media_id: @raw_message.dig("audio", "id")
      )

      return nil if transcript.blank?

      @whatsapp_message.update!(body: transcript)

      transcript
    end
end
