class DtApi::Resources::Projekts
  BASE_PATH = "/projekts".freeze

  def initialize(client)
    @client = client
  end

  def updated(projekt_id, serialized_projekt)
    @client.patch_with_auth(
      "#{BASE_PATH}/#{projekt_id}/projekt_updated",
      body: { projekt: serialized_projekt }
    )
  end

  def destroyed(projekt_id)
    @client.delete_with_auth(
      "#{BASE_PATH}/#{projekt_id}/projekt_destroyed"
    )
  end
end
