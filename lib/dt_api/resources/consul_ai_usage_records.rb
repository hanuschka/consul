class DtApi::Resources::ConsulAiUsageRecords
  BASE_PATH = "/consul_ai_usage_records".freeze

  def initialize(client)
    @client = client
  end

  def create_batch(records)
    @client.post(BASE_PATH, body: { consul_ai_usage_records: records })
  end
end
