class Whatsapp::TranscribeVoiceService < ApplicationService
  def initialize(media_id:)
    @media_id = media_id
  end

  def call
    return if @media_id.blank?

    media = WhatsappApi::Client.new.media.download(@media_id, max_bytes: ::Whatsapp.max_voice_bytes)

    return if media.blank?

    transcribe(media)
  rescue StandardError => e
    Rails.logger.error("[Whatsapp] transcription failed: #{e.class} - #{e.message}")
    Sentry.capture_exception(e, extra: { media_id: @media_id })

    nil
  end

  private

    def transcribe(media)
      tempfile = Tempfile.new(["whatsapp_voice", extension_for(media[:mime_type])])
      tempfile.binmode
      tempfile.write(media[:body])
      tempfile.flush

      transcription = RubyLLM.transcribe(
        tempfile.path,
        model: ::Whatsapp.transcription_model,
        language: I18n.locale.to_s.first(2),
        provider: :openai,
        assume_model_exists: true,
        context: Ai::RubyLlmFactory.openai_context
      )

      transcription.text.presence
    ensure
      if tempfile.present?
        tempfile.close
        tempfile.unlink
      end
    end

    def extension_for(mime_type)
      case mime_type.to_s
      when /ogg/ then ".ogg"
      when /mpeg/, /mp3/ then ".mp3"
      when /mp4/, /m4a/ then ".m4a"
      when /wav/ then ".wav"
      else ".ogg"
      end
    end
end
