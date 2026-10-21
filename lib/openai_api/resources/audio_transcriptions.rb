require "marcel"

class OpenaiApi::Resources::AudioTranscriptions
  PATH = "audio/transcriptions".freeze

  def initialize(client)
    @client = client
  end

  def create(file:, model:, language: nil, timeout: nil)
    body = { model: model, language: language, file: file_part(file) }.compact

    ::OpenaiApi::Transcription.new(
      @client.post_multipart(PATH, body: body, timeout: timeout)
    )
  end

  private

    # The provider refuses an upload whose format it cannot name, and a part
    # Faraday was told nothing about is announced as application/octet-stream.
    # Marcel reads the file's own bytes as well as its extension, so a voice
    # note saved with the wrong suffix is still recognised.
    def file_part(file)
      path = ::Pathname.new(file.to_s)

      ::Faraday::Multipart::FilePart.new(
        path.to_s,
        ::Marcel::MimeType.for(path, name: path.basename.to_s),
        path.basename.to_s
      )
    end
end
