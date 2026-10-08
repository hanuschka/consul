# The provider groups its audio endpoints under one path segment, and the client
# reads `audio.transcriptions.create`. This is that segment and nothing else.
class OpenaiApi::Resources::Audio
  def initialize(client)
    @client = client
  end

  def transcriptions
    @transcriptions ||= ::OpenaiApi::Resources::AudioTranscriptions.new(@client)
  end
end
