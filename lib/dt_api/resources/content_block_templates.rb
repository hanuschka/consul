class DtApi::Resources::ContentBlockTemplates
  BASE_PATH = "/content_block_templates".freeze

  def initialize(client)
    @client = client
  end

  def all
    @client.get(BASE_PATH)
  end
end
