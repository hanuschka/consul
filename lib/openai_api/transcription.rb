class OpenaiApi::Transcription
  def initialize(body)
    @body = body
  end

  def text
    @body["text"]
  end
end
