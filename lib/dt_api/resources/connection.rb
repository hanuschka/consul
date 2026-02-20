class DtApi::Resources::Connection
  BASE_PATH = "/connection".freeze

  def initialize(client)
    @client = client
  end

  def status
    @client.get("#{BASE_PATH}/status")
  end
end
