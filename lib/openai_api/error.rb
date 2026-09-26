# Every failure of the transport arrives as this one class: a refused request, a
# non-2xx answer and a body that is not the JSON it claimed to be are all the
# same thing to a caller, which either got an answer or has to fall through to
# its own "the model said nothing usable" path. The router's rescue turns it
# into a Sentry report and answers the citizen deterministically.
class OpenaiApi::Error < StandardError
  attr_reader :status, :body

  def initialize(message, status: nil, body: nil)
    @status = status
    @body = body

    super(message)
  end
end
