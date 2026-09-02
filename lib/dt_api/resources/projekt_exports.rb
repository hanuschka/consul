class DtApi::Resources::ProjektExports
  BASE_PATH = "/projekt_exports".freeze

  def initialize(client)
    @client = client
  end

  # Deliberately uncached: DtApi::Caching keeps a response for five months and
  # falls back to it on error, which for an import would mean rebuilding a
  # projekt from a structure the source changed long ago.
  def fetch(source_url)
    @client.post(BASE_PATH, body: { source_url: source_url })
  end
end
