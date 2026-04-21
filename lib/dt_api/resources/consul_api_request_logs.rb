class DtApi::Resources::ConsulApiRequestLogs
  BASE_PATH = "/consul_api_request_logs".freeze

  def initialize(client)
    @client = client
  end

  def create(attrs)
    @client.post(BASE_PATH, body: { consul_api_request_log: attrs })
  end
end
