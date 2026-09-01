class Mitmachbox::Resources::Base
  def initialize(client)
    @client = client
  end

  private

    attr_reader :client

    # Ids reach these resources straight from request params. Percent-encode
    # every interpolated path segment so a crafted id (containing "/", "..",
    # "?"…) can't escape the intended path and reach other API endpoints with
    # the org-wide token.
    def segment(value)
      ERB::Util.url_encode(value.to_s)
    end
end
