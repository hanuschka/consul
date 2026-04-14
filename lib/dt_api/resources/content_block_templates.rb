class DtApi::Resources::ContentBlockTemplates
  BASE_PATH = "/content_block_templates".freeze

  def initialize(client)
    @client = client
  end

  def all(section: nil)
    query = {}
    query[:section] = section if section.present?

    @client.get(BASE_PATH, query: query.presence)
  end
end
