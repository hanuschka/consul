require "faraday"
require "json"

module OgcApiFeatures
  USER_AGENT = "Consul-Masterportal/#{Rails.version}"
  CONNECT_TIMEOUT = 10
  READ_TIMEOUT = 30
  COLLECTIONS_CACHE_TTL = 5.minutes

  module Client
    module_function

    def list_collections(endpoint_url)
      cache_key = "ogc_api_features/collections/#{Digest::SHA256.hexdigest(endpoint_url)}"

      Rails.cache.fetch(cache_key, expires_in: COLLECTIONS_CACHE_TTL) do
        response = connection.get(File.join(endpoint_url, "collections"), f: "json")
        raise_on_error!(response)
        parse_collections(JSON.parse(response.body))
      end
    end

    def describe_collection(endpoint_url, collection_id)
      response = connection.get(
        File.join(endpoint_url, "collections", collection_id),
        f: "json"
      )
      raise_on_error!(response)
      JSON.parse(response.body)
    end

    def fetch_features(endpoint_url, collection_id, limit: 1000, &block)
      if !block_given?
        return enum_for(:fetch_features, endpoint_url, collection_id, limit: limit)
      end

      url = File.join(endpoint_url, "collections", collection_id, "items")
      params = { f: "json", limit: limit }

      loop do
        response = connection.get(url, params)
        raise_on_error!(response)
        body = JSON.parse(response.body)

        (body["features"] || []).each(&block)

        next_link = Array(body["links"]).find { |link| link["rel"] == "next" }
        break if next_link.nil?

        url = next_link["href"]
        params = {}
      end
    end

    def connection
      @connection ||= Faraday.new do |f|
        f.options.timeout = READ_TIMEOUT
        f.options.open_timeout = CONNECT_TIMEOUT
        f.headers["User-Agent"] = USER_AGENT
        f.headers["Accept"] = "application/json"
        f.adapter Faraday.default_adapter
      end
    end

    def raise_on_error!(response)
      return if response.success?

      raise OgcApiFeatures::Error,
            "OGC API request failed: #{response.status} #{response.reason_phrase}"
    end

    def parse_collections(body)
      (body["collections"] || []).map do |coll|
        {
          id: coll["id"],
          title: coll["title"],
          description: coll["description"],
          number_matched: coll["numberMatched"],
          extent: coll["extent"],
          links: coll["links"],
          parent: nil,
          children: []
        }
      end
    end
  end
end
